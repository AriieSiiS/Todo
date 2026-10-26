local Grid=dofile('kindle/todo.koplugin/covergrid.lua')
assert(Grid.percent({percent_finished=.14})=='14%')
assert(Grid.percent({})=='0%')
assert(Grid.percent({status='complete',percent_finished=.8})=='100%')
assert(Grid.percent({percent_finished=0/0})=='0%')
assert(Grid.percent({filepath='/leido.epub',menu={getBookInfo=function(file)
    assert(file=='/leido.epub'); return {percent_finished=.14}
end}})=='14%', 'El progreso es correcto incluso mientras se extrae una portada nueva')
local freed,painted=0,0
local Frame={}
function Frame:new(value)
    value.getSize=function() return {w=40,h=24} end
    value.paintTo=function(self,bb,x,y) painted=painted+1; self.last={x,y}; bb.text=self[1].text end
    value.free=function() freed=freed+1 end
    return value
end
package.loaded['ui/widget/container/framecontainer']=Frame
package.loaded['ui/widget/textwidget']={new=function(_,value) return value end}
package.loaded['ui/font']={getFace=function() return {} end}
package.loaded.device={screen={scaleBySize=function(_,value) return value end}}
package.loaded['ffi/blitbuffer']={COLOR_WHITE=255,COLOR_BLACK=0}
local native_paints,native_frees=0,0
local item={percent_finished=.14,show_progress_bar=true,do_hint_opened=true,has_description=true,
    {{{dimen={x=20,y=30,w=200,h=300}}}},
    paintTo=function() native_paints=native_paints+1 end,
    free=function() native_frees=native_frees+1 end}
local menu={todo_cover_grid=true,layout={{item}}}
local native_builds=0
package.loaded.mosaicmenu={_updateItemsBuildUI=function() native_builds=native_builds+1; return 4 end}
Grid.install()
Grid.install()
assert(package.loaded.mosaicmenu._updateItemsBuildUI(menu)==4)
assert(not item.show_progress_bar and not item.do_hint_opened and not item.has_description,
    'La portada solo añade la insignia de porcentaje')
local bb={}
item:paintTo(bb,0,0)
assert(bb.text=='14%' and native_paints==1 and painted==1)
assert(item.todo_progress_badge.last[1]==177 and item.todo_progress_badge.last[2]==33,
    'El porcentaje se ancla a la esquina de la portada, no a la celda')
item:paintTo(bb,0,0)
assert(freed==0, 'Repintar reutiliza la insignia')
item.percent_finished=.2
item:paintTo(bb,0,0)
assert(bb.text=='20%' and freed==1, 'Actualizar el progreso sustituye la insignia anterior')
item:free()
assert(freed==2 and native_frees==1)
local untouched={layout={{item}}}
package.loaded.mosaicmenu._updateItemsBuildUI(untouched)
assert(native_builds==2, 'Las otras cuadrículas conservan su construcción nativa')
print('Portadas: porcentaje, anclaje, actualización y liberación de recursos verificados')
