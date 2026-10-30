<template>
  <div class="layout-columns-aside">
    <el-scrollbar>
      <Logo />
      <ul>
        <li
          v-for="(v, k) in columnsAsideList"
          :key="k"
          @click="onColumnsAsideMenuClick(v)"
          ref="columnsAsideOffsetTopRefs"
          class="layout-columns"
          :class="{ 'layout-columns-active': v.k === liIndex }"
          :title="v.title"
        >
          <div :class="setColumnsAsidelayout">
            <i :class="'el-icon-' + v.icon"></i>
            <div class="font13">
              {{
                v.title && v.title.length >= 4
                  ? v.title.substr(0, setColumnsAsidelayout === 'columns-vertical' ? 4 : 3)
                  : v.title
              }}
            </div>
          </div>
        </li>
        <div ref="columnsAsideActiveRef" :class="setColumnsAsideStyle"></div>
      </ul>
    </el-scrollbar>
  </div>
</template>

<script>
import { getMenuSider, getHeaderName, findFirstNonNullChildren } from '@/utils/system.js';
import Logo from '@/layout/logo/index.vue';
import { mapState } from 'vuex';

export default {
  name: 'layoutColumnsAside',
  components: { Logo },
  data() {
    return {
      columnsAsideList: [],
      liIndex: 0,
      difference: 0,
      routeSplit: [],
    };
  },
  computed: {
    // 设置分栏高亮风格
    setColumnsAsideStyle() {
      return this.$store.state.themeConfig.themeConfig.columnsAsideStyle;
    },
    // 设置分栏布局风格
    setColumnsAsidelayout() {
      return this.$store.state.themeConfig.themeConfig.columnsAsideLayout;
    },
    Layout() {
      return this.$store.state.themeConfig.themeConfig.Layout;
    },
    routesList() {
      this.$store.state.user.menuList;
    },
    ...mapState('menu', ['activePath']),
  },
  beforeDestroy() {
    this.bus.$off('routesListChange');
  },
  mounted() {
    this.bus.$on('routesListChange', () => {
      this.setFilterRoutes();
    });
    this.setFilterRoutes();
    // this.$store
    //   .dispatch('user/getMenus', {
    //     that: this,
    //   })
    //   .then((res) => {
    //     this.setFilterRoutes();
    //   });
  },
  methods: {
    // 设置菜单高亮位置移动
    setColumnsAsideMove(k) {
      if (k === undefined) return false;
      const els = this.$refs.columnsAsideOffsetTopRefs;
      this.liIndex = k;
      this.$refs.columnsAsideActiveRef.style.top = `${els[k].offsetTop + this.difference}px`;
    },
    // 菜单高亮点击事件
    onColumnsAsideMenuClick(v) {
      let { path, redirect } = v;
      if (v.children.length) {
        this.$router.push(findFirstNonNullChildren(v.children).path);
      } else {
        this.$router.push(path);
      }
      // 一个路由设置自动收起菜单
      if (!v.children || v.children.length <= 1) this.$store.state.themeConfig.themeConfig.isCollapse = true;
      else if (v.children.length > 1) this.$store.state.themeConfig.themeConfig.isCollapse = false;
    },
    // 设置高亮动态位置
    onColumnsAsideDown(k) {
      this.$nextTick(() => {
        this.setColumnsAsideMove(k);
      });
    },
    // 设置/过滤路由（非静态路由/是否显示在菜单中）
    setFilterRoutes() {
      if (this.$store.state.user.menuList.length <= 0) return false;
      this.columnsAsideList = this.filterRoutesFun(this.$store.state.user.menuList);
      const resData = this.setSendChildren(getHeaderName(this.$route, this.columnsAsideList));
      if (!resData.children) {
        this.bus.$emit('setSendColumnsChildren', []);
        this.$store.commit('user/childMenuList', []);

        this.$store.state.themeConfig.themeConfig.isCollapse = true;
        return false;
      }
      this.bus.$emit('oneCatName', resData.item[0].title);
      this.onColumnsAsideDown(resData.item[0].k);
      // 刷新时，初始化一个路由设置自动收起菜单
      resData.children.length > 0
        ? (this.$store.state.themeConfig.themeConfig.isCollapse = false)
        : (this.$store.state.themeConfig.themeConfig.isCollapse = true);
      this.bus.$emit('setSendColumnsChildren', resData.children || []);
      this.$store.commit('user/childMenuList', resData.children || []);
    },
    // 传送当前子级数据到菜单中
    setSendChildren(path) {
      let currentData = {};
      this.columnsAsideList.map((v, k) => {
        v['k'] = k;
        if (v.path === path) {
          currentData['item'] = [{ ...v }];
          if (v.children) currentData['children'] = v.children;
        }
      });
      return currentData;
    },
    // 路由过滤递归函数
    filterRoutesFun(arr) {
      return arr
        .filter((item) => item.path)
        .map((item) => {
          item = Object.assign({}, item);
          if (item.children.length) item.children = this.filterRoutesFun(item.children);
          return item;
        });
    },
    // tagsView 点击时，根据路由查找下标 columnsAsideList，实现左侧菜单高亮
    setColumnsMenuHighlight(path) {
      const currentSplitRoute = this.columnsAsideList.find((v) => v.path === path);
      if (!currentSplitRoute) {
        // this.onColumnsAsideDown(0);
        return false;
      }
      // 延迟拿值，防止取不到
      setTimeout(() => {
        this.onColumnsAsideDown(currentSplitRoute.k);
      }, 0);
    },
  },
  watch: {
    // 监听 vuex 数据变化
    '$store.state': {
      handler(val) {
        val.themeConfig.themeConfig.columnsAsideStyle === 'columnsRound'
          ? (this.difference = 3)
          : (this.difference = 0);
        if (val.user.menuList.length === this.columnsAsideList.length) return false;
      },
      deep: true,
    },
    // 监听路由的变化
    $route: {
      handler(to) {
        this.setColumnsMenuHighlight(to.path);
        let HeadName = getHeaderName(to, this.columnsAsideList);
        let asideList = getMenuSider(this.columnsAsideList, HeadName)[0].children;
        const resData = this.setSendChildren(HeadName);
        if (resData.item) {
          this.onColumnsAsideDown(resData.item[0].k);
          this.bus.$emit('oneCatName', resData.item[0].title);
        } else {
          this.onColumnsAsideDown(0);
        }
        this.$store.commit('user/childMenuList', asideList || []);
      },
      deep: true,
    },
  },
};
</script>

<style scoped lang="scss">
/* ============================================================
 * StorApp 重绘 —— 左侧分栏图标轨
 *
 * 为什么改：原来 80px + columns-horizontal，.font13 在 79px 的 flex 行里
 * 只剩 52px，被压到 26px 后折行，和下一个条目的图标叠在一起（看着像一团糊）。
 * 现在：108px 宽 + 竖排（图标在上、文字在下）+ 选中态浅 teal 底 + 右侧主色条。
 * ============================================================ */
.layout-columns-aside {
  width: 108px;
  height: 100%;
  background: #ffffff;
  border-right: 1px solid var(--prev-border-color-lighter);
  z-index: 20;
  ul {
    position: relative;
    li {
      color: var(--prev-bg-columnsMenuBarColor);
      width: 100%;
      height: 62px;
      text-align: center;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      position: relative;
      z-index: 1;
      /* 竖排：图标 + 文案垂直居中 */
      .columns-vertical {
        margin: 0 auto;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        width: 100%;
        i {
          display: block;
          font-size: 18px;
          line-height: 18px;
          color: inherit;
          transition: color 0.2s ease;
        }
        .font13,
        .columns-vertical-title {
          margin-top: 6px;
          padding-top: 0;
          font-size: 12px !important;
          line-height: 14px !important;
          letter-spacing: 0;
          /* 关键：不折行、不被压缩 */
          white-space: nowrap;
          word-break: keep-all;
          flex: 0 0 auto;
        }
      }
      /* 横排（后台设置里仍可切回来）：图标不压缩、文字不折行 */
      .columns-horizontal {
        display: flex;
        height: 62px;
        width: 100%;
        align-items: center;
        justify-content: flex-start;
        padding: 0 10px;
        i {
          flex: 0 0 auto;
          font-size: 16px;
          margin-right: 7px;
        }
        a {
          display: flex;
          flex: 0 0 auto;
          .columns-horizontal-title {
            padding-top: 0;
            font-size: 12px !important;
            white-space: nowrap;
            word-break: keep-all;
          }
        }
      }
      &:hover {
        background: rgba(13, 148, 136, 0.06);
        i {
          color: var(--prev-color-primary);
        }
      }
      a {
        text-decoration: none;
        color: var(--prev-bg-columnsMenuBarColor);
      }
    }
    // li:hover {
    //   background: var(--prev-color-primary);
    //   color: var(--prev-bg-columnsMenuBarColor);
    // }
    .layout-columns {
      transition: color 0.3s ease-in-out, background 0.3s ease-in-out;
      &:hover {
        color: var(--prev-color-primary);
      }
    }
    /* 选中态：不要整块实心色，改成浅 teal 底 + 主色文字 + 右侧主色条 */
    .layout-columns-active,
    .layout-columns-active a {
      color: var(--prev-color-primary);
      font-weight: 600;
      transition: color 0.3s ease-in-out;
    }

    .columns-round {
      background: rgba(13, 148, 136, 0.1);
      position: absolute;
      left: 50%;
      top: 0;
      height: 62px;
      width: 100%;
      transform: translateX(-50%);
      z-index: 0;
      transition: 0.3s ease-in-out;
      border-radius: 0;
      border-right: 3px solid var(--prev-color-primary);
    }
    .columns-card {
      @extend .columns-round;
      top: 0;
      height: 62px;
      width: 100%;
      border-radius: 0;
    }
  }
}
</style>
