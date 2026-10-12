/* ============================================================================
 *  dsh-todo-widget —— Client 半边（正式插件包，__ModuleLoader__ bundle）
 * ----------------------------------------------------------------------------
 *  注册进 'shell.overlay'（frame 级悬浮层，list 槽，纯追加）。
 *  数据持久化用 localStorage（浏览器本地，跨会话、跨重启保留）：
 *     key: 'dsh-todo-items'  →  { items: [...] }
 *  首次无数据时用内置 SEED。无需 host RPC，纯客户端自给自足。
 * ========================================================================== */
window.__ModuleLoader__.load({
  id: '@local/dsh-todo-widget/client',
  factory: (require) => {
    var module = { exports: {} }
    var exports = module.exports
    var react = require('react')

    var STORAGE_KEY = 'dsh-todo-items'

    var SEED = [
      { id: 1, text: '【编译】case_E_logout_50u —— 从未编译过，明天先编它', done: false },
      { id: 2, text: '【编译】case_C_login_50u —— 明天要跑，场景配置照搬用例 D', done: false },
      { id: 3, text: '【编译】case_A / case_B / case_D —— 顺手一起编译', done: false },
      { id: 4, text: '【运行】用例 C：50 并发 / 5 分钟 / 登录处集合点', done: false },
      { id: 5, text: '【报告】用例 D 的 Analysis 导出 HTML（交付物）', done: false },
      { id: 6, text: '【补数据】被测服务器 CPU/内存 ≤ 80%（Windows，手动观察）', done: false },
    ]

    function sanitize(list) {
      var out = []
      if (!list || typeof list.length !== 'number') return out
      for (var i = 0; i < list.length; i++) {
        var it = list[i]
        if (!it || typeof it !== 'object') continue
        var id = typeof it.id === 'number' ? it.id : i + 1
        var text = typeof it.text === 'string' ? it.text : ''
        if (text === '') continue
        out.push({ id: id, text: text, done: it.done === true })
      }
      return out
    }

    function loadItems() {
      try {
        var raw = localStorage.getItem(STORAGE_KEY)
        if (raw) {
          var parsed = JSON.parse(raw)
          var items = sanitize(parsed && parsed.items)
          if (items.length > 0) return items
        }
      } catch (_e) { /* fall through to seed */ }
      return sanitize(SEED)
    }

    function saveItems(items) {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify({ items: sanitize(items) }))
        return true
      } catch (_e) {
        return false
      }
    }

    /* ---------- 注入 ---------- */
    exports.inject = ['slots']

    /* ---------- 样式 ---------- */
    var CSS = [
      '.dsh-todo-root{position:fixed;width:344px;max-height:64vh;',
      'display:flex;flex-direction:column;pointer-events:auto;z-index:9000;',
      'font-size:13px;line-height:1.55;font-family:inherit;',
      'color:var(--dsw-alias-label-primary);background:var(--dsw-alias-bg-overlay);',
      'border:1px solid var(--dsw-alias-border-l1);border-radius:10px;',
      'box-shadow:0 10px 32px rgba(0,0,0,.20);overflow:hidden;}',
      '.dsh-todo-head{display:flex;align-items:center;gap:8px;padding:9px 12px;cursor:pointer;',
      'user-select:none;background:var(--dsw-alias-bg-layer-2);',
      'border-bottom:1px solid var(--dsw-alias-border-l1);}',
      '.dsh-todo-head:hover{background:var(--dsw-alias-bg-layer-1);}',
      '.dsh-todo-title{font-weight:600;flex:1;}',
      '.dsh-todo-count{font-size:11px;color:var(--dsw-alias-label-secondary);',
      'font-variant-numeric:tabular-nums;}',
      '.dsh-todo-chev{font-size:10px;color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-new{display:flex;gap:6px;padding:9px 10px 6px;}',
      '.dsh-todo-new input{flex:1;min-width:0;padding:5px 8px;font:inherit;',
      'color:var(--dsw-alias-label-primary);background:var(--dsw-alias-bg-layer-1);',
      'border:1px solid var(--dsw-alias-border-l1);border-radius:6px;outline:none;}',
      '.dsh-todo-new input:focus{border-color:var(--dsw-alias-brand-primary);}',
      '.dsh-todo-btn{padding:5px 10px;font:inherit;cursor:pointer;border-radius:6px;',
      'border:1px solid var(--dsw-alias-border-l1);background:var(--dsw-alias-bg-layer-1);',
      'color:var(--dsw-alias-label-primary);}',
      '.dsh-todo-btn:hover{border-color:var(--dsw-alias-brand-primary);}',
      '.dsh-todo-btn:disabled{opacity:.45;cursor:default;}',
      '.dsh-todo-filters{display:flex;gap:4px;padding:2px 10px 8px;}',
      '.dsh-todo-chip{padding:2px 9px;font-size:11px;cursor:pointer;border-radius:999px;',
      'border:1px solid transparent;background:transparent;',
      'color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-chip:hover{background:var(--dsw-alias-bg-layer-1);}',
      '.dsh-todo-chip.on{background:var(--dsw-alias-bg-layer-1);',
      'border-color:var(--dsw-alias-border-l2);color:var(--dsw-alias-label-primary);}',
      '.dsh-todo-list{list-style:none;margin:0;padding:0 6px 6px;overflow-y:auto;flex:1;}',
      '.dsh-todo-item{display:flex;align-items:flex-start;gap:7px;padding:5px 6px;border-radius:6px;}',
      '.dsh-todo-item:hover{background:var(--dsw-alias-bg-layer-1);}',
      '.dsh-todo-item.done .dsh-todo-text{text-decoration:line-through;',
      'color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-text{flex:1;word-break:break-word;white-space:pre-wrap;}',
      '.dsh-todo-acts{display:flex;gap:2px;opacity:0;flex:0 0 auto;}',
      '.dsh-todo-item:hover .dsh-todo-acts{opacity:1;}',
      '.dsh-todo-icon{width:20px;height:20px;padding:0;font-size:12px;line-height:1;',
      'cursor:pointer;border:none;background:transparent;border-radius:4px;',
      'color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-icon:hover{background:var(--dsw-alias-bg-layer-2);',
      'color:var(--dsw-alias-label-primary);}',
      '.dsh-todo-icon.del:hover{color:var(--dsw-alias-state-error-primary);}',
      '.dsh-todo-check{width:15px;height:15px;margin:3px 0 0;flex:0 0 auto;cursor:pointer;',
      'accent-color:var(--dsw-alias-brand-primary);}',
      '.dsh-todo-edit{flex:1;min-width:0;padding:3px 6px;font:inherit;',
      'color:var(--dsw-alias-label-primary);background:var(--dsw-alias-bg-base);',
      'border:1px solid var(--dsw-alias-brand-primary);border-radius:5px;outline:none;}',
      '.dsh-todo-foot{display:flex;align-items:center;justify-content:space-between;',
      'gap:8px;padding:7px 10px;font-size:11px;',
      'color:var(--dsw-alias-label-secondary);',
      'border-top:1px solid var(--dsw-alias-border-l1);',
      'background:var(--dsw-alias-bg-layer-2);}',
      '.dsh-todo-link{cursor:pointer;background:none;border:none;padding:0;font:inherit;',
      'color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-link:hover{color:var(--dsw-alias-state-error-primary);}',
      '.dsh-todo-err{padding:6px 10px;font-size:11px;',
      'color:var(--dsw-alias-state-error-primary);}',
      '.dsh-todo-empty{padding:14px 10px;text-align:center;font-size:12px;',
      'color:var(--dsw-alias-label-secondary);}',
      '.dsh-todo-empty{padding:14px 10px;text-align:center;font-size:12px;',
      'color:var(--dsw-alias-label-secondary);}',

      /* 拖拽：root 跟随定位（inline style 覆盖 right/bottom），标题栏可拖动 */
      '.dsh-todo-head{cursor:grab;}',
      '.dsh-todo-head:active{cursor:grabbing;}',
      '.dsh-todo-head:active{user-select:none;}',

      /* 折叠球：圆形悬浮球，可拖动 */
      '.dsh-todo-ball{position:fixed;z-index:9000;width:52px;height:52px;border-radius:50%;',
      'display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;',
      'pointer-events:auto;cursor:grab;touch-action:none;user-select:none;',
      'font-size:20px;line-height:1;color:var(--dsw-alias-label-primary);',
      'background:var(--dsw-alias-bg-overlay);border:1px solid var(--dsw-alias-border-l2);',
      'box-shadow:0 8px 24px rgba(0,0,0,.25);}',
      '.dsh-todo-ball:active{cursor:grabbing;}',
      '.dsh-todo-ball:hover{box-shadow:0 10px 30px rgba(0,0,0,.32);}',
      '.dsh-todo-ball-badge{font-size:10px;line-height:1;color:var(--dsw-alias-brand-primary);',
      'font-variant-numeric:tabular-nums;font-weight:600;}',
    ].join('')

    /* ---------- 组件 ---------- */
    exports.apply = function (ctx) {
      var e = react.createElement

      /* 样式表随本次挂载 / 卸载 */
      ctx.effect(function () {
        var style = document.createElement('style')
        style.textContent = CSS
        document.head.appendChild(style)
        return function () { style.remove() }
      }, 'todos.styles')

      function TodoWidget(_props) {
        var itemsState = react.useState(null)
        var items = itemsState[0]
        var setItems = itemsState[1]

        var collapsedState = react.useState(false)
        var collapsed = collapsedState[0]
        var setCollapsed = collapsedState[1]

        var draftState = react.useState('')
        var draft = draftState[0]
        var setDraft = draftState[1]

        var editingState = react.useState(null)
        var editingId = editingState[0]
        var setEditingId = editingState[1]

        var editingTextState = react.useState('')
        var editingText = editingTextState[0]
        var setEditingText = editingTextState[1]

        var filterState = react.useState('all')
        var filter = filterState[0]
        var setFilter = filterState[1]

        var errorState = react.useState('')
        var error = errorState[0]
        var setError = errorState[1]

        /* 位置 state：默认右上角；localStorage 持久化。用 set 标记区分"是否拖过" */
        var POS_KEY = 'dsh-todo-pos'
        var posState = react.useState(function () {
          try {
            var raw = localStorage.getItem(POS_KEY)
            if (raw) {
              var p = JSON.parse(raw)
              if (typeof p.left === 'number' && typeof p.top === 'number') {
                /* 兼容旧格式（无 set 字段，当时存的是 {left,top}） */
                return { set: true, left: p.left, top: p.top }
              }
              if (p && p.set === true && typeof p.left === 'number' && typeof p.top === 'number') return p
            }
          } catch (_e) { /* fall through */ }
          return { set: false, left: 0, top: 0 }
        })
        var pos = posState[0]
        var setPos = posState[1]

        /* 拖拽：记录起始鼠标位置与窗口位置 */
        var dragRef = react.useRef(null)
        /* 拖动超过 3px 视为拖拽，吞掉随后的 click（避免误折叠/展开） */
        var suppressClickRef = react.useRef(false)
        var DRAG_THRESHOLD = 3

        function bindDrag(targetRect, setter) {
          dragRef.current = {
            startX: 0, startY: 0,
            left: targetRect.left, top: targetRect.top,
            dx: 0, dy: 0, moved: false,
          }
          function onMove(me) {
            var d = dragRef.current
            if (!d) return
            d.dx = me.clientX - d.startX
            d.dy = me.clientY - d.startY
            if (Math.abs(d.dx) > DRAG_THRESHOLD || Math.abs(d.dy) > DRAG_THRESHOLD) {
              d.moved = true
              suppressClickRef.current = true
            }
            setter({ set: true, left: d.left + d.dx, top: d.top + d.dy })
          }
          function onUp() {
            var d = dragRef.current
            if (d) {
              try {
                localStorage.setItem(POS_KEY, JSON.stringify({ set: true, left: d.left + d.dx, top: d.top + d.dy }))
              } catch (_e) { /* ignore */ }
            }
            dragRef.current = null
            document.removeEventListener('mousemove', onMove)
            document.removeEventListener('mouseup', onUp)
          }
          document.addEventListener('mousemove', onMove)
          document.addEventListener('mouseup', onUp)
        }

        function onHeadMouseDown(ev) {
          if (ev.button !== 0) return
          ev.preventDefault()
          var rect = ev.currentTarget.closest('.dsh-todo-root').getBoundingClientRect()
          bindDrag(rect, setPos)
          dragRef.current.startX = ev.clientX
          dragRef.current.startY = ev.clientY
        }

        function onBallMouseDown(ev) {
          if (ev.button !== 0) return
          ev.preventDefault()
          ev.stopPropagation()
          var rect = ev.currentTarget.getBoundingClientRect()
          bindDrag(rect, setPos)
          dragRef.current.startX = ev.clientX
          dragRef.current.startY = ev.clientY
        }

        /* 吞掉拖拽后的 click */
        function consumeClick(ev) {
          ev.stopPropagation()
          if (suppressClickRef.current) {
            suppressClickRef.current = false
            return true
          }
          return false
        }

        react.useEffect(function () {
          setItems(loadItems())
        }, [])

        function commit(next) {
          setItems(next)
          if (!saveItems(next)) {
            setError('保存失败：localStorage 不可用')
          } else {
            setError('')
          }
        }

        function nextId(list) {
          var max = 0
          for (var i = 0; i < list.length; i++) { if (list[i].id > max) { max = list[i].id } }
          return max + 1
        }

        function add() {
          var text = draft.replace(/^\s+|\s+$/g, '')
          if (!text || !items) return
          commit(items.concat([{ id: nextId(items), text: text, done: false }]))
          setDraft('')
        }

        function toggle(id) {
          if (!items) return
          commit(items.map(function (it) {
            return it.id === id ? { id: it.id, text: it.text, done: !it.done } : it
          }))
        }

        function remove(id) {
          if (!items) return
          commit(items.filter(function (it) { return it.id !== id }))
          if (editingId === id) { setEditingId(null); setEditingText('') }
        }

        function beginEdit(it) { setEditingId(it.id); setEditingText(it.text) }

        function saveEdit() {
          var text = editingText.replace(/^\s+|\s+$/g, '')
          if (text && items) {
            commit(items.map(function (it) {
              return it.id === editingId ? { id: it.id, text: text, done: it.done } : it
            }))
          }
          setEditingId(null)
          setEditingText('')
        }

        function clearDone() {
          if (!items) return
          commit(items.filter(function (it) { return !it.done }))
        }

        var list = items || []
        var total = list.length
        var doneCount = list.filter(function (it) { return it.done }).length
        var shown = filter === 'todo' ? list.filter(function (it) { return !it.done })
          : filter === 'done' ? list.filter(function (it) { return it.done })
            : list

        var head = e('div', {
          className: 'dsh-todo-head',
          onClick: function (ev) {
            if (consumeClick(ev)) return
            setCollapsed(!collapsed)
          },
          onMouseDown: onHeadMouseDown,
          title: collapsed ? '展开待办清单' : '收起待办清单'
        },
          e('span', { className: 'dsh-todo-title' }, '📋 待办清单'),
          e('span', { className: 'dsh-todo-count' }, doneCount + ' / ' + total),
          e('span', { className: 'dsh-todo-chev' }, collapsed ? '▲' : '▼')
        )

        /* 位置：组件左上角锚点（球与面板共用）。pos 有值 = 拖过，存实测 left/top */
        var PANEL_W = 344
        var PANEL_EST_H = 420   /* 估算高度用于 clamp（max-height 66vh 上下限之间） */
        var BALL_SIZE = 52

        function clampPos(left, top, w, h) {
          var vw = typeof window !== 'undefined' ? window.innerWidth : 1280
          var vh = typeof window !== 'undefined' ? window.innerHeight : 800
          return {
            left: Math.max(4, Math.min(left, vw - w - 4)),
            top: Math.max(4, Math.min(top, vh - h - 4)),
          }
        }

        /* 展开面板位置：直接是锚点，clamp 到视口内（球靠右时面板贴右，不藏屏幕外） */
        var rootStyle
        if (pos.set === true) {
          var p = clampPos(pos.left, pos.top, PANEL_W, PANEL_EST_H)
          rootStyle = { left: p.left + 'px', top: p.top + 'px' }
        } else {
          rootStyle = { right: '18px', top: '18px' }
        }

        /* 折叠：渲染成圆形球球，可拖动，点击展开 */
        if (collapsed) {
          var todoCount = total - doneCount
          var ballStyle
          if (pos.set === true) {
            var b = clampPos(pos.left, pos.top, BALL_SIZE, BALL_SIZE)
            ballStyle = { left: b.left + 'px', top: b.top + 'px' }
          } else {
            ballStyle = { right: '18px', top: '18px' }
          }
          return e('div', {
            className: 'dsh-todo-ball',
            style: ballStyle,
            onClick: function (ev) {
              if (consumeClick(ev)) return
              setCollapsed(false)
            },
            onMouseDown: onBallMouseDown,
            title: '展开待办清单（' + todoCount + ' 项待办）'
          },
            e('span', null, '📋'),
            e('span', { className: 'dsh-todo-ball-badge' }, todoCount > 0 ? String(todoCount) : '')
          )
        }

        var newRow = e('div', { className: 'dsh-todo-new' },
          e('input', {
            type: 'text',
            value: draft,
            placeholder: '添加一条待办，回车确认…',
            onChange: function (ev) { setDraft(ev.target.value) },
            onKeyDown: function (ev) { if (ev.key === 'Enter') { add() } }
          }),
          e('button', { className: 'dsh-todo-btn', onClick: add, disabled: !draft.replace(/^\s+|\s+$/g, '') }, '添加')
        )

        function chip(key, text) {
          return e('button', {
            key: key,
            className: 'dsh-todo-chip' + (filter === key ? ' on' : ''),
            onClick: function () { setFilter(key) }
          }, text)
        }

        var filters = e('div', { className: 'dsh-todo-filters' },
          chip('all', '全部 ' + total),
          chip('todo', '待办 ' + (total - doneCount)),
          chip('done', '已完成 ' + doneCount)
        )

        var rows = shown.map(function (it) {
          var editing = editingId === it.id

          var left = editing
            ? e('input', {
              className: 'dsh-todo-edit',
              type: 'text',
              value: editingText,
              autoFocus: true,
              onChange: function (ev) { setEditingText(ev.target.value) },
              onKeyDown: function (ev) {
                if (ev.key === 'Enter') { saveEdit() }
                if (ev.key === 'Escape') { setEditingId(null); setEditingText('') }
              }
            })
            : e('input', {
              className: 'dsh-todo-check',
              type: 'checkbox',
              checked: it.done,
              onChange: function () { toggle(it.id) },
              title: it.done ? '标记为未完成' : '标记为已完成'
            })

          var body = editing ? null : e('span', { className: 'dsh-todo-text' }, it.text)

          var acts = editing
            ? e('div', { className: 'dsh-todo-acts' },
              e('button', { className: 'dsh-todo-icon', onClick: saveEdit, title: '保存' }, '✔'),
              e('button', { className: 'dsh-todo-icon', onClick: function () { setEditingId(null); setEditingText('') }, title: '取消' }, '✕')
            )
            : e('div', { className: 'dsh-todo-acts' },
              e('button', { className: 'dsh-todo-icon', onClick: function () { beginEdit(it) }, title: '修改' }, '✎'),
              e('button', { className: 'dsh-todo-icon del', onClick: function () { remove(it.id) }, title: '删除' }, '🗑')
            )

          return e('li', { key: String(it.id), className: 'dsh-todo-item' + (it.done ? ' done' : '') },
            left, body, acts
          )
        })

        if (items === null) {
          rows = [e('div', { key: 'loading', className: 'dsh-todo-empty' }, '载入中…')]
        } else if (shown.length === 0) {
          rows = [e('div', { key: 'empty', className: 'dsh-todo-empty' },
            total === 0 ? '还没有待办，在上面添加一条' : '此分类下没有条目')]
        }

        var listEl = e('ul', { className: 'dsh-todo-list' }, rows)

        var foot = e('div', { className: 'dsh-todo-foot' },
          e('span', null, filter === 'done' ? '' : '剩余 ' + (total - doneCount) + ' 项'),
          doneCount > 0
            ? e('button', { className: 'dsh-todo-link', onClick: clearDone }, '清除已完成 (' + doneCount + ')')
            : null
        )

        return e('div', { className: 'dsh-todo-root', style: rootStyle },
          head,
          error ? e('div', { className: 'dsh-todo-err' }, error) : null,
          newRow,
          filters,
          listEl,
          foot
        )
      }

      /* shell.overlay 由 ui-layout 声明；用 slots.inject 等它出现后再注册 */
      ctx.slots.inject('shell.overlay', function () {
        return ctx.slots.register({
          name: 'shell.overlay',
          id: 'dsh-todo-widget',
          order: 100,
          label: '待办清单'
        }, TodoWidget)
      })
    }

    return module.exports
  }
})
