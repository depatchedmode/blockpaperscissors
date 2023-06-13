// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

contract BlockPaperScissors {
  enum Move {
    Stalemate,
    Block,
    Paper,
    Scissors
  }

  struct User {
    address accountAddress;
    Move lastMove;
    uint256 totalMoves;
    uint256 lastMoveBlockHeight;
  }

  struct BlockResult {
    uint256 blockHeight;
    Move winningMove;
    uint256 blockVotes;
    uint256 paperVotes;
    uint256 scissorsVotes;
    address[] blockVoters;
    address[] paperVoters;
    address[] scissorsVoters;
    bool isStalemate;
    bool isDraw;
    Move previousWinningMove;
  }

  struct Streak {
    uint256 startBlockHeight;
    uint256 endBlockHeight;
    uint256 length;
    Move lastWinningMove;
  }

  mapping(uint256 => BlockResult) public blockResults;
  mapping(address => User) public users;
  Streak[] public winningStreaks;

  address[] public allUsers;
  uint256 public lastWinningMoveBlockHeight;
  Move public lastWinningMove;

  function castVote(Move move, uint256 blockHeight) public {
    require(move >= Move.Block && move <= Move.Scissors, 'Invalid move');
    require(blockHeight <= block.number, 'Invalid block height');
    
    if (blockHeight == 0) blockHeight = block.number;

    User storage user = users[msg.sender];
    if (user.totalMoves == 0) {
      allUsers.push(msg.sender);
    }
    if (user.totalMoves == 0 || user.lastMoveBlockHeight < blockHeight) {
      user.accountAddress = msg.sender;
      user.lastMoveBlockHeight = blockHeight;
    }
    user.lastMove = move;
    user.totalMoves++;

    // Calculate network streak for the given block height
    calculateNetworkStreak(blockHeight);
  }

  function calculateNetworkStreak(uint256 blockHeight) internal {
    uint256 blockCount;
    uint256 paperCount;
    uint256 scissorsCount;
    address[] memory blockVoters = new address[](allUsers.length);
    address[] memory paperVoters = new address[](allUsers.length);
    address[] memory scissorsVoters = new address[](allUsers.length);

    for (uint256 i = 0; i < allUsers.length; i++) {
      User memory user = users[allUsers[i]];
      if (user.lastMoveBlockHeight == blockHeight) {
        if (user.lastMove == Move.Block) {
          blockCount++;
          blockVoters[i] = user.accountAddress;
        } else if (user.lastMove == Move.Paper) {
          paperCount++;
          paperVoters[i] = user.accountAddress;
        } else if (user.lastMove == Move.Scissors) {
          scissorsCount++;
          scissorsVoters[i] = user.accountAddress;
        }
      }
    }

    // Update the winning move based on the vote counts
    if (blockCount > paperCount && blockCount > scissorsCount) {
      recordBlockResult(
        blockHeight,
        Move.Block,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        false,
        false,
        lastWinningMove
      );
      lastWinningMoveBlockHeight = blockHeight;
      updateWinningStreak(Move.Block);
      lastWinningMove = Move.Block;
    } else if (paperCount > blockCount && paperCount > scissorsCount) {
      recordBlockResult(
        blockHeight,
        Move.Paper,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        false,
        false,
        lastWinningMove
      );
      lastWinningMoveBlockHeight = blockHeight;
      updateWinningStreak(Move.Paper);
      lastWinningMove = Move.Paper;
    } else if (scissorsCount > blockCount && scissorsCount > paperCount) {
      recordBlockResult(
        blockHeight,
        Move.Scissors,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        false,
        false,
        lastWinningMove
      );
      lastWinningMoveBlockHeight = blockHeight;
      updateWinningStreak(Move.Scissors);
      lastWinningMove = Move.Scissors;
    } else if (blockCount == paperCount && blockCount > scissorsCount) {
      recordBlockResult(
        blockHeight,
        Move.Stalemate,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        true,
        false,
        lastWinningMove
      );
    } else if (blockCount == scissorsCount && blockCount > paperCount) {
      recordBlockResult(
        blockHeight,
        Move.Stalemate,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        true,
        false,
        lastWinningMove
      );
    } else if (paperCount == scissorsCount && paperCount > blockCount) {
      recordBlockResult(
        blockHeight,
        Move.Stalemate,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        true,
        false,
        lastWinningMove
      );
    } else if (blockCount == paperCount && blockCount == scissorsCount) {
      recordBlockResult(
        blockHeight,
        Move.Stalemate,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        true,
        false,
        lastWinningMove
      );
    } else {
      recordBlockResult(
        blockHeight,
        lastWinningMove,
        blockCount,
        paperCount,
        scissorsCount,
        blockVoters,
        paperVoters,
        scissorsVoters,
        false,
        true,
        lastWinningMove
      );
    }
  }

  function recordBlockResult(
    uint256 blockHeight,
    Move winningMove,
    uint256 blockVotes,
    uint256 paperVotes,
    uint256 scissorsVotes,
    address[] memory blockVoters,
    address[] memory paperVoters,
    address[] memory scissorsVoters,
    bool isStalemate,
    bool isDraw,
    Move previousWinningMove
  ) internal {
    BlockResult storage blockResult = blockResults[blockHeight];
    blockResult.blockHeight = blockHeight;
    blockResult.winningMove = winningMove;
    blockResult.blockVotes = blockVotes;
    blockResult.paperVotes = paperVotes;
    blockResult.scissorsVotes = scissorsVotes;
    blockResult.blockVoters = blockVoters;
    blockResult.paperVoters = paperVoters;
    blockResult.scissorsVoters = scissorsVoters;
    blockResult.isStalemate = isStalemate;
    blockResult.isDraw = isDraw;
    blockResult.previousWinningMove = previousWinningMove;
  }

  function updateWinningStreak(Move move) internal {
    if (winningStreaks.length == 0) {
      Streak memory newStreak = Streak({
        startBlockHeight: lastWinningMoveBlockHeight,
        endBlockHeight: lastWinningMoveBlockHeight,
        length: 1,
        lastWinningMove: move
      });
      winningStreaks.push(newStreak);
    } else {
      Streak storage currentStreak = winningStreaks[winningStreaks.length - 1];
      if (
        (move == Move.Block && lastWinningMove == Move.Scissors) ||
        (move == Move.Paper && lastWinningMove == Move.Block) ||
        (move == Move.Scissors && lastWinningMove == Move.Paper)
      ) {
        currentStreak.endBlockHeight = lastWinningMoveBlockHeight;
        currentStreak.length++;
        currentStreak.lastWinningMove = move;
      } else {
        Streak memory newStreak = Streak({
          startBlockHeight: lastWinningMoveBlockHeight,
          endBlockHeight: lastWinningMoveBlockHeight,
          length: 0,
          lastWinningMove: move
        });
        winningStreaks.push(newStreak);
      }
    }
  }

  function getAllUsers() public view returns (User[] memory) {
    User[] memory allUsersData = new User[](allUsers.length);
    for (uint256 i = 0; i < allUsers.length; i++) {
      allUsersData[i] = users[allUsers[i]];
    }
    return allUsersData;
  }

  function getUserByAddress(
    address userAddress
  ) public view returns (User memory) {
    return users[userAddress];
  }

  function getTopStreaks(uint256 count) public view returns (Streak[] memory) {
    require(count > 0, 'Invalid count');
    uint256 totalStreaks = count > winningStreaks.length
      ? winningStreaks.length
      : count;
    Streak[] memory streaksToIterate = winningStreaks;

    // Sort the winningStreaks array in descending order based on length
    for (uint256 i = 0; i < totalStreaks - 1; i++) {
      for (uint256 j = i + 1; j < totalStreaks; j++) {
        if (winningStreaks[j].length > winningStreaks[i].length) {
          Streak memory temp = streaksToIterate[i];
          streaksToIterate[i] = streaksToIterate[j];
          streaksToIterate[j] = temp;
        }
      }
    }

    // Create a new array with the top streaks
    Streak[] memory topStreaks = new Streak[](totalStreaks);
    for (uint256 i = 0; i < totalStreaks; i++) {
      topStreaks[i] = winningStreaks[i];
    }
    return topStreaks;
  }

  function getBlockResult(
    uint256 blockheight
  ) public view returns (BlockResult memory) {
    return blockResults[blockheight];
  }

  function getResultsOfPreviousBlocks(
    uint256 count
  ) public view returns (BlockResult[] memory) {
    require(
      count <= lastWinningMoveBlockHeight,
      'Count exceeds available block results'
    );
    BlockResult[] memory results = new BlockResult[](count);
    for (uint256 i = 0; i < count; i++) {
      results[i] = blockResults[block.number - i];
      results[i].blockHeight = block.number - i;
    }
    return results;
  }

  function getAllStreaks() public view returns (Streak[] memory) {
    return winningStreaks;
  }
}
