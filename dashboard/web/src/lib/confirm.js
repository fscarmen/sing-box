let impl = options => Promise.resolve(window.confirm(options.message))
export function registerConfirm(fn) { impl = fn }
export const confirmAction = options => impl(options)
