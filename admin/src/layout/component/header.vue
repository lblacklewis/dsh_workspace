<template>
  <el-header class="layout-header" :height="setHeaderHeight">
    <NavBarsIndex />
  </el-header>
</template>

<script>
import NavBarsIndex from '@/layout/navBars/index.vue';
export default {
  name: 'layoutHeader',
  components: { NavBarsIndex },
  data() {
    return {};
  },
  computed: {
    // 设置顶部 header 的具体高度
    // StorApp 重绘：原来带 tagsView 时是 84px（面包屑 50 + tags 34），
    // 压到 68px（50 + 18 的紧凑 tags 条），把纵向空间让给内容区。
    setHeaderHeight() {
      let { isTagsview, layout } = this.$store.state.themeConfig.themeConfig;
      if (isTagsview && layout !== 'classic') return '68px';
      else return '50px';
    },
  },
};
</script>
