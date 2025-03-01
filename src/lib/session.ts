import type { EthereumClient } from '@web3modal/ethereum'
import type { Web3Modal } from '@web3modal/html'
import { get as getStore } from 'svelte/store'
import { goto } from '$app/navigation'

import { sessionStore } from '../stores'
import { addNotification } from '$lib/notifications'

export type Session = {
  address: string
  authed: boolean
  loading: boolean
  error: boolean
  ethereumClient: EthereumClient
  web3modal: Web3Modal
}

export const PUBLIC_ROUTES = [
  '',
  '/',
  '/choose-team/',
  '/filecoin/connect/',
  '/filecoin/intro/',
  '/ethereum/connect/',
  '/ethereum/intro/',
  '/polygon/connect/',
  '/polygon/intro/',
]

/**
 * Ask the user to connect their metamask so we can populate the sessionStore
 */
export const initialise: () => Promise<void> = async () => {
  try {
    // sessionStore.update(state => ({ ...state, loading: true }))

    sessionStore.update(state => ({
      ...state,
      authed: false,
      loading: false
    }))
  } catch (error) {
    console.error(error)
    sessionStore.update(state => ({ ...state, error: true, loading: false }))
    addNotification(error.message, 'error')
    throw new Error(error)
  }
}

/**
 * Disconnect the user from their webnative session, reset the sessionStore and go to homepage
 */
export const disconnect: () => Promise<void> = async () => {
  sessionStore.update(state => ({
    ...state,
    address: null,
    authed: false,
    loading: false,
    error: false
  }))

  goto('/')
}

/**
 * Copy the user's address to the clipboard
 */
export const copyAddressToClipboard: () => Promise<void> = async () => {
  try {
    const session = getStore(sessionStore)
    await navigator.clipboard.writeText(session.address)
    addNotification('Address copied to clipboard', 'success')
  } catch (error) {
    console.error(error)
    addNotification('Failed to copy address to clipboard', 'error')
  }
}
