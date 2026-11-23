import { post } from './api.js'
import { toast } from './state.js'
import { confirmAction } from './confirm.js'

export async function banFlow(ip, unban, reason = '', duration = 0) {
  const ok = await confirmAction(unban
    ? { title: '解除封禁', message: '解除 ' + ip + ' 的封禁？其新连接将恢复正常。', confirm: '解除' }
    : { title: '封禁 ' + ip, message: '将断开该地址的在线节点连接，并拒绝其新建连接（直连入口与 CDN 入口）。不影响 SSH 和本面板。', confirm: '封禁', danger: true })
  if (!ok) return false
  try {
    const r = await post('api/ban', { ip, action: unban ? 'unban' : 'ban', reason, duration })
    toast(unban ? '已解除封禁 ' + r.target : '已封禁 ' + r.target + (r.closed ? '，断开 ' + r.closed + ' 条连接' : ''), 'ok')
    return true
  } catch (e) {
    toast(e.message, 'error')
    return false
  }
}
