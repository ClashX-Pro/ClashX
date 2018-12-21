package main // import "github.com/yichengchen/clashX/ClashX"
import (
	"C"

	"github.com/Dreamacro/clash/hub"
)
import "github.com/Dreamacro/clash/hub/route"

var (
	homedir string
)

//export run
func run() *C.char {

	if err := hub.Parse(); err != nil {
		return C.CString(err.Error())
	}

	return C.CString("success")
}

//export setUIPath
func setUIPath(path *C.char) {
	route.SetUIPath(C.GoString(path))
}

func main() {

}
