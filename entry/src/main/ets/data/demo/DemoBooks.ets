import { Book, BookFormat } from '../../domain/model/Book';

// Fictional layout fixtures with original SVG artwork; these are not API responses.
export function createDemoBooks(): Book[] {
  return [
    new Book('demo-epub', '山海之间', '林屿', BookFormat.EPUB,
      '沿着山的轮廓与海的呼吸，找回生活本来的节奏。', '', true, 'cover-01.png', 0.75, '#E8EEE7'),
    new Book('demo-pdf', '设计的日常', '周以', BookFormat.PDF,
      '在一把椅子、一束光里，看见设计的温度。', '', true, 'cover-02.png', 0.88, '#EDF0F7'),
    new Book('demo-guide', '慢慢来，也很好', '苏禾', BookFormat.EPUB,
      '不用赶路的日子，也有自己的风景。', '', true, 'cover-03.png', 0.73, '#FAF0E9'),
    new Book('demo-universe', '万物的尺度', '陈知远', BookFormat.PDF,
      '从一粒沙到一颗星，重新认识我们身处的世界。', '', true, 'cover-04.png', 0.8, '#E9EDF0'),
    new Book('demo-montage', '生活蒙太奇', '沈未', BookFormat.EPUB,
      '把散落的生活，拼成自己的故事。', '', true, 'cover-05.png', 0.78, '#F0E9E9'),
    new Book('demo-stars', '星河手记', '许星野', BookFormat.EPUB,
      '关于时间、远方与我们的好奇。', '', true, 'cover-06.png', 0.71, '#E8ECF6'),
    new Book('demo-room', '一间自己的房间', '陆青', BookFormat.EPUB,
      '给自己一点空间，让想法自由生长。', '', true, 'cover-07.png', 0.77, '#EAF0E8'),
    new Book('demo-reading', '读书是件好事', '余白', BookFormat.EPUB,
      '总有一本书，能陪你走过一段路。', '', true, 'cover-08.png', 0.85, '#F5F0E6'),
    new Book('demo-forest', '树木与森林', '简木', BookFormat.PDF,
      '听见万物缓慢生长的声音。', '', true, 'cover-09.png', 0.74, '#ECEDE6'),
    new Book('demo-time', '时间的形状', '江时', BookFormat.EPUB,
      '关于记忆、当下，以及那些被我们忽略的片刻。', '', true, 'cover-10.png', 0.8, '#EAF0FA'),
    new Book('demo-seasons', '山居四季', '叶南', BookFormat.EPUB,
      '春天的雨、夏天的风，和一整年的好时光。', '', true, 'cover-11.png', 0.76, '#EFF1E9'),
    new Book('demo-city', '城市漫游指南', '方野', BookFormat.PDF,
      '走一条不熟悉的路，遇见这座城市的另一面。', '', true, 'cover-12.png', 0.83, '#F4E9E3')
  ];
}
