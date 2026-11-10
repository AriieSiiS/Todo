local Defaults=dofile('kindle/todo.koplugin/readerdefaults.lua')
local source={font_face='Noto Serif',font_family_fonts={serif='Noto Serif'},css='./data/epub.css',
    copt_font_size=22,copt_h_page_margins={30,30},copt_t_page_margin=20,copt_b_page_margin=20,
    copt_line_spacing=100,partial_md5_checksum='identidad',last_xpointer='/p[81]',
    percent_finished=.1,annotations={{text='Una cita'}},pagemap_chars_per_synthetic_page=1989}
local values=Defaults.values(source)
assert(values.cre_font=='Noto Serif' and values.copt_font_size==22)
assert(values.copt_h_page_margins[1]==30 and values.copt_line_spacing==100)
assert(values.copt_css=='./data/epub.css' and values.cre_font_family_fonts.serif=='Noto Serif')
assert(not values.partial_md5_checksum and not values.last_xpointer and not values.annotations
    and not values.percent_finished and not values.pagemap_chars_per_synthetic_page,
    'Solo se guardan valores de composición, sin mezclar identidad ni progreso')
values.copt_h_page_margins[1]=50
assert(source.copt_h_page_margins[1]==30,'Los valores por defecto no editan el libro de origen')
print('Predeterminados: composición actual, claves nativas e identidad independiente verificados')
