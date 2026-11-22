import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

struct PhotoTransform: Codable, Equatable {
    var zoom: Double = 1
    var x: Double = 0
    var y: Double = 0
    init(zoom: Double = 1, x: Double = 0, y: Double = 0) { self.zoom = zoom; self.x = x; self.y = y }
    enum CodingKeys: String, CodingKey { case zoom, x, y }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        zoom = min(4,max(1,try c.decodeIfPresent(Double.self,forKey:.zoom) ?? 1))
        x = min(1,max(-1,try c.decodeIfPresent(Double.self,forKey:.x) ?? 0))
        y = min(1,max(-1,try c.decodeIfPresent(Double.self,forKey:.y) ?? 0))
    }
}
struct Card: Codable, Identifiable, Equatable {
    var id = UUID()
    var showIntro = true
    var intro = ""
    var topic = ""
    var heading = ""
    var introSize: Double = 31
    var topicSize: Double = 39
    var headingSize: Double = 56
    var layout = "Одна фотография"
    var text = ""
    var textSize: Double = 42
    var image1: Data? = nil
    var image2: Data? = nil
    var image3: Data? = nil
    var photoEdit1 = PhotoTransform()
    var photoEdit2 = PhotoTransform()
    var photoEdit3 = PhotoTransform()
    var imageMode1 = "Растянуть"
    var imageMode2 = "Растянуть"
    var imageMode3 = "Растянуть"
    var photoArrangement = "Рядом"

    enum CodingKeys: String, CodingKey { case id, showIntro, intro, topic, heading, introSize, topicSize, headingSize, layout, text, textSize, image1, image2, image3, imageMode1, imageMode2, imageMode3, photoEdit1, photoEdit2, photoEdit3, photoArrangement }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey:.id) ?? UUID()
        showIntro = try c.decodeIfPresent(Bool.self, forKey:.showIntro) ?? true
        intro = try c.decodeIfPresent(String.self, forKey:.intro) ?? ""
        topic = try c.decodeIfPresent(String.self, forKey:.topic) ?? ""
        heading = try c.decodeIfPresent(String.self, forKey:.heading) ?? ""
        introSize = try c.decodeIfPresent(Double.self, forKey:.introSize) ?? 31
        topicSize = try c.decodeIfPresent(Double.self, forKey:.topicSize) ?? 39
        headingSize = try c.decodeIfPresent(Double.self, forKey:.headingSize) ?? 56
        layout = try c.decodeIfPresent(String.self, forKey:.layout) ?? "Одна фотография"
        text = try c.decodeIfPresent(String.self, forKey:.text) ?? ""
        textSize = try c.decodeIfPresent(Double.self, forKey:.textSize) ?? 42
        image1 = try c.decodeIfPresent(Data.self, forKey:.image1)
        image2 = try c.decodeIfPresent(Data.self, forKey:.image2)
        image3 = try c.decodeIfPresent(Data.self, forKey:.image3)
        photoEdit1 = try c.decodeIfPresent(PhotoTransform.self,forKey:.photoEdit1) ?? PhotoTransform()
        photoEdit2 = try c.decodeIfPresent(PhotoTransform.self,forKey:.photoEdit2) ?? PhotoTransform()
        photoEdit3 = try c.decodeIfPresent(PhotoTransform.self,forKey:.photoEdit3) ?? PhotoTransform()
        imageMode1 = try c.decodeIfPresent(String.self, forKey:.imageMode1) ?? "Растянуть"
        imageMode2 = try c.decodeIfPresent(String.self, forKey:.imageMode2) ?? "Растянуть"
        imageMode3 = try c.decodeIfPresent(String.self, forKey:.imageMode3) ?? "Растянуть"
        photoArrangement = try c.decodeIfPresent(String.self, forKey:.photoArrangement) ?? "Рядом"
    }
    func image(_ number: Int) -> Data? { number == 1 ? image1 : (number == 2 ? image2 : image3) }
    func mode(_ number: Int) -> String { number == 1 ? imageMode1 : (number == 2 ? imageMode2 : imageMode3) }
    func edit(_ number: Int) -> PhotoTransform { number == 1 ? photoEdit1 : (number == 2 ? photoEdit2 : photoEdit3) }
    mutating func setImage(_ number:Int, _ data:Data?) { if number == 1 { image1 = data } else if number == 2 { image2 = data } else { image3 = data } }
    mutating func setEdit(_ number:Int, _ value:PhotoTransform) { if number == 1 { photoEdit1 = value } else if number == 2 { photoEdit2 = value } else { photoEdit3 = value } }
    var usesExtendedPhotos: Bool { layout == "Три фотографии с наложением" || image3 != nil || photoEdit1 != PhotoTransform() || photoEdit2 != PhotoTransform() || photoEdit3 != PhotoTransform() }
}
enum SheetMode: String, Codable { case portrait, landscape }
struct Project: Codable, Equatable {
    var version = 1
    var cards = [Card()]
    var marginMM: Double = 5
    var sheetMode: SheetMode = .portrait
    enum CodingKeys: String, CodingKey { case version, cards, marginMM, sheetMode }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        version = try c.decodeIfPresent(Int.self,forKey:.version) ?? 1
        cards = try c.decodeIfPresent([Card].self,forKey:.cards) ?? [Card()]
        marginMM = try c.decodeIfPresent(Double.self,forKey:.marginMM) ?? 5
        sheetMode = try c.decodeIfPresent(SheetMode.self,forKey:.sheetMode) ?? .portrait
    }
    var pageCount: Int { sheetMode == .landscape ? max(1,(cards.count+1)/2) : 1 }
    func page(for selected:Int) -> Int { sheetMode == .landscape ? min(max(0,selected/2),pageCount-1) : 0 }
}

struct HistoryEntry {
    let project: Project
    let selected: Int
}
final class Store: ObservableObject {
    @Published var project = Project() {
        willSet { recordChange(to: newValue) }
    }
    private var undoHistory: [HistoryEntry] = []
    private var redoHistory: [HistoryEntry] = []
    private var applyingHistory = false
    private var groupingHistory = false
    private var groupHasChange = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    private let historyLimit = 50
    @Published var selected = 0
    @Published var status = "Выберите карточку и заполните её содержимое."
    @Published var preview: NSImage?
    var template: NSImage
    var lastSaveDirectory: URL?
    init() {
        guard let url = Bundle.main.url(forResource: "template", withExtension: "png"), let image = NSImage(contentsOf: url) else { fatalError("Не найден шаблон карточки") }
        template = image
        updatePreview()
    }
    func updatePreview() {
        let width = project.sheetMode == .landscape ? 1188 : 840
        preview = Renderer.sheet(project:project,template:template,width:width,margin:project.marginMM,page:project.page(for:selected))
    }
    func selectPage(_ page:Int) {
        guard project.sheetMode == .landscape, page >= 0, page < project.pageCount else { return }
        selected = min(page*2,project.cards.count-1)
        updatePreview()
    }
    private func updateHistoryButtons() { canUndo = !undoHistory.isEmpty; canRedo = !redoHistory.isEmpty }
    private func recordChange(to next: Project) {
        guard !applyingHistory && next != project else { return }
        if groupingHistory && groupHasChange { return }
        undoHistory.append(HistoryEntry(project:project, selected:selected))
        if undoHistory.count > historyLimit { undoHistory.removeFirst() }
        redoHistory.removeAll(); if groupingHistory { groupHasChange = true }; updateHistoryButtons()
    }
    func beginHistoryGroup() { groupingHistory = true; groupHasChange = false }
    func endHistoryGroup() { groupingHistory = false; groupHasChange = false }
    func undo() {
        guard let previous = undoHistory.popLast() else { return }
        redoHistory.append(HistoryEntry(project:project, selected:selected))
        applyingHistory = true; project = previous.project; selected = min(max(0,previous.selected),project.cards.count-1); applyingHistory = false
        updateHistoryButtons(); status = "Действие отменено."
    }
    func redo() {
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(HistoryEntry(project:project, selected:selected))
        applyingHistory = true; project = next.project; selected = min(max(0,next.selected),project.cards.count-1); applyingHistory = false
        updateHistoryButtons(); status = "Действие повторено."
    }
    func add() {
        if project.cards.count >= 4 {
            let a = NSAlert(); a.messageText = "Набор заполнен"; a.informativeText = "В наборе уже четыре карточки. Сохраните проект и экспортируйте готовые листы, прежде чем начать новый набор. Создать новый набор?"
            a.addButton(withTitle: "Сохранить проект и создать"); a.addButton(withTitle: "Создать без сохранения"); a.addButton(withTitle: "Отмена")
            let result = a.runModal()
            if result == .alertFirstButtonReturn { guard saveProject() else { return }; project.cards = [Card()]; selected = 0 }
            else if result == .alertSecondButtonReturn { project.cards = [Card()]; selected = 0 }
        } else { project.cards.append(Card()); selected = project.cards.count - 1 }
    }
    func remove() {
        guard !project.cards.isEmpty else { return }
        let oldIndex = selected
        var remaining = project.cards
        remaining.remove(at:oldIndex)
        if remaining.isEmpty { remaining = [Card()] }
        project.cards = remaining
        selected = min(oldIndex, remaining.count-1)
    }
    func move(_ delta: Int) {
        let to = selected + delta
        guard project.cards.indices.contains(to) else { return }
        project.cards.swapAt(selected, to); selected = to
    }
    func copyHeadings(from sourceIndex: Int) {
        guard project.cards.indices.contains(sourceIndex), project.cards.indices.contains(selected), sourceIndex != selected else { return }
        let source = project.cards[sourceIndex]
        var target = project.cards[selected]
        target.intro = source.intro; target.topic = source.topic; target.heading = source.heading
        target.introSize = source.introSize; target.topicSize = source.topicSize; target.headingSize = source.headingSize
        project.cards[selected] = target
        status = "Строки и их размеры перенесены из карточки \(sourceIndex+1)."
    }
    @discardableResult func saveProject() -> Bool {
        let p = makeSavePanel(title: "Сохранить редактируемый проект", name: "Карточки.json", type: .json)
        guard p.runModal() == .OK, let url = p.url else { return false }
        do { try saveProject(to:url); lastSaveDirectory = url.deletingLastPathComponent(); status = "Проект сохранён: \(url.lastPathComponent)"; return true }
        catch { errorAlert(error); return false }
    }
    func makeSavePanel(title: String, name: String, type: UTType) -> NSSavePanel {
        let p = NSSavePanel(); p.title = title; p.message = "Выберите папку и при необходимости измените имя файла."; p.nameFieldLabel = "Имя файла:"; p.nameFieldStringValue = name; p.allowedContentTypes = [type]; p.isExtensionHidden = false; p.canCreateDirectories = true
        if let directory = lastSaveDirectory { p.directoryURL = directory }
        return p
    }
    func saveProject(to url: URL) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        var saved = project
        saved.version = saved.sheetMode == .landscape ? 3 : (saved.cards.contains(where: { $0.usesExtendedPhotos }) ? 2 : 1)
        try enc.encode(saved).write(to: url, options: .atomic)
    }
    func openProject() {
        let p = NSOpenPanel(); p.title = "Открыть проект"; p.allowedContentTypes = [.json, .data]; p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let loaded = try loadProject(from:url,keepingLegacyMode:project.sheetMode)
            selected = 0; project = loaded; lastSaveDirectory = url.deletingLastPathComponent(); status = "Проект открыт: \(url.lastPathComponent)"
        } catch { errorAlert(error) }
    }
    func loadProject(from url:URL, keepingLegacyMode mode:SheetMode) throws -> Project {
        var loaded = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
        guard [1,2,3].contains(loaded.version), (1...4).contains(loaded.cards.count), (0...20).contains(loaded.marginMM) else { throw NSError(domain:"CardMaker",code:1,userInfo:[NSLocalizedDescriptionKey:"Неподдерживаемый или повреждённый проект."]) }
        guard Set(loaded.cards.map(\.id)).count == loaded.cards.count else { throw NSError(domain:"CardMaker",code:4,userInfo:[NSLocalizedDescriptionKey:"В проекте есть карточки с одинаковыми идентификаторами."]) }
        if loaded.version < 3 { loaded.sheetMode = mode }
        return loaded
    }
    func setPhoto(_ number:Int, _ data:Data?) {
        var updated = project.cards[selected]; updated.setImage(number,data); updated.setEdit(number,PhotoTransform())
        project.cards[selected] = updated
    }
    func chooseImage(_ number: Int) {
        let p = NSOpenPanel(); p.title = "Выберите изображение"; p.allowedContentTypes = [.image]; p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        do { let data = try Data(contentsOf: url); guard Store.validImage(data) else { throw NSError(domain:"CardMaker", code:2, userInfo:[NSLocalizedDescriptionKey:"Не удалось прочитать изображение."]) }; setPhoto(number,data) }
        catch { errorAlert(error) }
    }
    static func imageData(from board: NSPasteboard) -> Data? {
        if let urls = board.readObjects(forClasses:[NSURL.self], options:[.urlReadingFileURLsOnly:true]) as? [URL],
           let url = urls.first, let data = try? Data(contentsOf:url), validImage(data) { return data }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = board.data(forType:type), validImage(data) { return data }
        }
        if let image = NSImage(pasteboard:board), let tiff = image.tiffRepresentation, validImage(tiff) { return tiff }
        return nil
    }
    static func validImage(_ data: Data) -> Bool {
        guard let image = NSImage(data:data) else { return false }
        return image.size.width.isFinite && image.size.height.isFinite && image.size.width > 0 && image.size.height > 0
    }
    func pasteImage(_ number: Int) {
        guard let data = Store.imageData(from: NSPasteboard.general) else {
            let a = NSAlert(); a.messageText = "В буфере нет изображения"; a.informativeText = "Скопируйте фотографию или файл изображения и попробуйте снова."; a.runModal(); return
        }
        setPhoto(number,data)
        status = "Фото \(number) вставлено из буфера обмена."
    }
    func export(margin: Double) {
        let twoPages = project.pageCount > 1
        let format = project.sheetMode == .landscape ? "A5" : "A6"
        let name = margin == 0 ? "Карточки-A4-точный-\(format).png" : "Карточки-A4-для-печати.png"
        let p = makeSavePanel(title:"Экспорт листов A4 в PNG",name:name,type:.png)
        if twoPages { p.message = "Выберите папку и основное имя. Будут сохранены файлы с номерами листов: -1 и -2." }
        guard p.runModal() == .OK, let url = p.url else { return }
        let urls = exportURLs(base:url,count:project.pageCount)
        let existing = urls.filter { FileManager.default.fileExists(atPath:$0.path) }
        if twoPages && !existing.isEmpty {
            let alert=NSAlert(); alert.messageText="Файлы уже существуют"; alert.informativeText="Заменить: " + existing.map(\.lastPathComponent).joined(separator:", ") + "?"; alert.addButton(withTitle:"Заменить"); alert.addButton(withTitle:"Отмена")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do { try exportAll(to:url,margin:margin); lastSaveDirectory = url.deletingLastPathComponent(); status = urls.count == 1 ? "Экспортировано: \(urls[0].lastPathComponent)" : "Экспортировано листов: \(urls.count)" } catch { errorAlert(error) }
    }
    func exportURLs(base:URL,count:Int) -> [URL] {
        guard count > 1 else { return [base] }
        let dir = base.deletingLastPathComponent(), stem = base.deletingPathExtension().lastPathComponent
        return (1...count).map { dir.appendingPathComponent("\(stem)-\($0).png") }
    }
    func export(to url:URL, margin:Double, page:Int = 0) throws {
        let width = project.sheetMode == .landscape ? 3508 : 2480
        guard let image = Renderer.sheet(project:project,template:template,width:width,margin:margin,page:page), let data = image.pngData() else { throw NSError(domain:"CardMaker",code:3,userInfo:[NSLocalizedDescriptionKey:"Не удалось создать PNG."]) }
        try data.write(to:url, options:.atomic)
    }
    func exportAll(to base:URL, margin:Double) throws {
        let urls = exportURLs(base:base,count:project.pageCount)
        for (page,url) in urls.enumerated() { try export(to:url,margin:margin,page:page) }
    }
    func errorAlert(_ error: Error) { let a = NSAlert(error: error); a.runModal() }
}

extension NSImage {
    func pngData() -> Data? {
        guard let rep = representations.first as? NSBitmapImageRep else { return nil }
        rep.size = NSSize(width: Double(rep.pixelsWide) / 300.0 * 72.0, height: Double(rep.pixelsHigh) / 300.0 * 72.0)
        return rep.representation(using: .png, properties: [:])
    }
}

enum Renderer {
    static let cw: CGFloat = 1055, ch: CGFloat = 1491
    struct SheetGeometry {
        let width: CGFloat, height: CGFloat, cardW: CGFloat, cardH: CGFloat, startX: CGFloat, startY: CGFloat
    }
    static func geometry(mode:SheetMode, width:Int, margin:Double) -> SheetGeometry {
        let w=CGFloat(width), landscape = mode == .landscape
        let h:CGFloat = landscape ? (width == 3508 ? 2480 : (w*210/297).rounded()) : (width == 2480 ? 3508 : (w*297/210).rounded())
        let mmWidth:CGFloat = landscape ? 297 : 210
        let m = CGFloat(margin)/mmWidth*w
        if landscape {
            let cw = min((w-2*m)/2,(h-2*m)*148.5/210)
            let ch = cw*210/148.5
            return SheetGeometry(width:w,height:h,cardW:cw,cardH:ch,startX:(w-2*cw)/2,startY:(h-ch)/2)
        }
        let cw = (w-2*m)/2, ch = cw*148.5/105
        return SheetGeometry(width:w,height:h,cardW:cw,cardH:ch,startX:m,startY:(h-2*ch)/2)
    }
    static func exportPixelScale(mode:SheetMode, margin:Double) -> CGFloat {
        let width = mode == .landscape ? 3508 : 2480
        return cw/geometry(mode:mode,width:width,margin:margin).cardW
    }
    static func sheet(project: Project, template: NSImage, width: Int, margin: Double, page:Int = 0) -> NSImage? {
        guard page >= 0, page < project.pageCount else { return nil }
        let g=geometry(mode:project.sheetMode,width:width,margin:margin)
        let height=Int(g.height)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:width, pixelsHigh:height, bitsPerSample:8, samplesPerPixel:4, hasAlpha:true, isPlanar:false, colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0), let cg = NSGraphicsContext(bitmapImageRep:rep)?.cgContext else { return nil }
        cg.translateBy(x:0,y:g.height); cg.scaleBy(x:1,y:-1)
        let ctx = NSGraphicsContext(cgContext:cg, flipped:true)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
        NSColor.white.setFill(); NSRect(x:0,y:0,width:g.width,height:g.height).fill()
        let start = project.sheetMode == .landscape ? page*2 : 0
        let count = project.sheetMode == .landscape ? 2 : 4
        let last = min(start+count,project.cards.count)
        if start < last {
            for (i, card) in project.cards[start..<last].enumerated() {
                let col = i % 2, row = project.sheetMode == .landscape ? 0 : i/2
                cg.saveGState(); cg.translateBy(x:g.startX+CGFloat(col)*g.cardW,y:g.startY+CGFloat(row)*g.cardH); cg.scaleBy(x:g.cardW/cw,y:g.cardH/ch)
                let outputWidth:CGFloat = project.sheetMode == .landscape ? 3508 : 2480
                let pixelScale = (g.width/outputWidth)*cw/g.cardW
                draw(card:card,template:template,cg:cg,pixelScale:pixelScale); cg.restoreGState()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size:NSSize(width:width,height:height)); image.addRepresentation(rep); return image
    }
    static func draw(card: Card, template: NSImage, cg: CGContext, pixelScale: CGFloat) {
        template.draw(in:NSRect(x:0,y:0,width:cw,height:ch), from:.zero, operation:.sourceOver, fraction:1, respectFlipped:true, hints:nil)
        let brown = NSColor(calibratedRed:0.49, green:0.35, blue:0.12, alpha:1)
        if card.showIntro {
            text(card.intro, rect:NSRect(x:180,y:100,width:695,height:48), size:card.introSize, color:brown, bold:false, center:true, shrink:true, italic:true)
            text(card.topic, rect:NSRect(x:130,y:151,width:795,height:60), size:card.topicSize, color:brown, bold:false, center:true, shrink:true)
            let gold = NSColor(calibratedRed:0.77,green:0.49,blue:0.05,alpha:1); gold.setStroke()
            let path = NSBezierPath(); path.lineWidth = 2; path.move(to:NSPoint(x:297,y:231)); path.line(to:NSPoint(x:502,y:231)); path.move(to:NSPoint(x:553,y:231)); path.line(to:NSPoint(x:759,y:231)); path.stroke()
            text("✝", rect:NSRect(x:504,y:205,width:49,height:55), size:43, color:gold,bold:true,center:true,shrink:true)
        }
        let hy: CGFloat = card.showIntro ? 264 : 135
        text(card.heading, rect:NSRect(x:90,y:hy,width:875,height:90), size:card.headingSize, color:brown,bold:true,center:true,shrink:true)
        let y: CGFloat = card.showIntro ? 407 : 245
        let region = NSRect(x:46,y:y,width:963,height:1188-y)
        switch card.layout {
        case "Две фотографии":
            for n in 1...2 { photo(card.image(n), in:photoRect(card,n), mode:card.mode(n), edit:card.edit(n),cg:cg,pixelScale:pixelScale) }
        case "Три фотографии с наложением":
            for n in 1...3 { photo(card.image(n), in:photoRect(card,n), mode:card.mode(n), edit:card.edit(n),cg:cg,pixelScale:pixelScale) }
        case "Только текст": body(card.text, rect:region, size:card.textSize)
        case "Фото слева, текст справа":
            let w = (region.width-12)/2
            photo(card.image1,in:photoRect(card,1),mode:card.imageMode1,edit:card.photoEdit1,cg:cg,pixelScale:pixelScale)
            body(card.text,rect:NSRect(x:region.minX+w+12,y:y,width:w,height:region.height),size:card.textSize)
        case "Фото сверху, текст снизу":
            let h = (region.height-12)/2
            photo(card.image1,in:photoRect(card,1),mode:card.imageMode1,edit:card.photoEdit1,cg:cg,pixelScale:pixelScale)
            body(card.text,rect:NSRect(x:region.minX,y:y+h+12,width:region.width,height:h),size:card.textSize)
        default: photo(card.image1,in:photoRect(card,1),mode:card.imageMode1,edit:card.photoEdit1,cg:cg,pixelScale:pixelScale)
        }
    }
    static func photoRect(_ card: Card, _ number: Int) -> NSRect {
        let y: CGFloat = card.showIntro ? 407 : 245
        let region = NSRect(x:46,y:y,width:963,height:1188-y)
        let gap: CGFloat = 12
        switch card.layout {
        case "Две фотографии":
            if card.photoArrangement == "Сверху вниз" {
                let h = (region.height-gap)/2
                return NSRect(x:region.minX,y:y+CGFloat(number-1)*(h+gap),width:region.width,height:h)
            }
            let w = (region.width-gap)/2
            return NSRect(x:region.minX+CGFloat(number-1)*(w+gap),y:y,width:w,height:region.height)
        case "Три фотографии с наложением":
            let w = region.width * 0.38, h = region.height * 0.96
            return NSRect(x:region.minX+CGFloat(number-1)*(region.width-w)/2,y:y+CGFloat(number-1)*(region.height-h)/2,width:w,height:h)
        case "Фото слева, текст справа": return NSRect(x:region.minX,y:y,width:(region.width-gap)/2,height:region.height)
        case "Фото сверху, текст снизу": return NSRect(x:region.minX,y:y,width:region.width,height:(region.height-gap)/2)
        default: return region
        }
    }
    static func photoDestination(data:Data, image:NSImage, rect:NSRect, mode:String, edit:PhotoTransform, pixelScale:CGFloat) -> (NSRect, NSSize) {
        let inner = rect.insetBy(dx:4,dy:4)
        var w = inner.width, h = inner.height
        if mode == "Исходный размер (1:1)" {
            let dimensions = pixelDimensions(data, fallback:image.size)
            w = dimensions.width * pixelScale; h = dimensions.height * pixelScale
        } else if mode != "Растянуть" {
            let sx = inner.width/image.size.width, sy = inner.height/image.size.height
            let scale = mode == "Обрезать края" ? max(sx,sy) : min(sx,sy)
            w = image.size.width*scale; h = image.size.height*scale
        }
        w *= CGFloat(edit.zoom); h *= CGFloat(edit.zoom)
        let travel = NSSize(width:abs(w-inner.width)/2,height:abs(h-inner.height)/2)
        let dest = NSRect(x:inner.midX-w/2+CGFloat(edit.x)*travel.width,y:inner.midY-h/2+CGFloat(edit.y)*travel.height,width:w,height:h)
        return (dest,travel)
    }
    static func photo(_ data: Data?, in rect: NSRect, mode:String, edit:PhotoTransform = PhotoTransform(), cg: CGContext, pixelScale: CGFloat) {
        guard let data = data, let image = NSImage(data:data), image.size.width > 0, image.size.height > 0 else { return }
        let border = NSBezierPath(roundedRect:rect,xRadius:12,yRadius:12)
        NSColor(calibratedRed:0.79,green:0.53,blue:0.04,alpha:1).setStroke(); border.lineWidth = 3; border.stroke()
        let inner = rect.insetBy(dx:4,dy:4)
        cg.saveGState(); NSBezierPath(roundedRect:inner,xRadius:8,yRadius:8).addClip()
        let dest = photoDestination(data:data,image:image,rect:rect,mode:mode,edit:edit,pixelScale:pixelScale).0
        image.draw(in:dest, from:.zero, operation:.sourceOver, fraction:1, respectFlipped:true, hints:[.interpolation:NSImageInterpolation.high])
        cg.restoreGState()
    }
    static func photoPreview(card:Card, number:Int, margin:Double, mode:SheetMode = .portrait) -> NSImage? {
        let rect = photoRect(card,number)
        let width = 600, height = max(1,Int((600*rect.height/rect.width).rounded()))
        guard height < 3000, let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0), let cg = NSGraphicsContext(bitmapImageRep:rep)?.cgContext else { return nil }
        cg.translateBy(x:0,y:CGFloat(height)); cg.scaleBy(x:1,y:-1)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:cg,flipped:true)
        NSColor(calibratedRed:1,green:0.98,blue:0.93,alpha:1).setFill(); NSRect(x:0,y:0,width:width,height:height).fill()
        let scale = CGFloat(width)/rect.width; cg.scaleBy(x:scale,y:scale)
        let pixelScale = exportPixelScale(mode:mode,margin:margin)
        photo(card.image(number),in:NSRect(x:0,y:0,width:rect.width,height:rect.height),mode:card.mode(number),edit:card.edit(number),cg:cg,pixelScale:pixelScale)
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size:NSSize(width:width,height:height)); out.addRepresentation(rep); return out
    }
    static func pixelDimensions(_ data: Data, fallback: NSSize) -> NSSize {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString:Any], let w = props[kCGImagePropertyPixelWidth] as? NSNumber, let h = props[kCGImagePropertyPixelHeight] as? NSNumber else { return fallback }
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation) ? NSSize(width:h.doubleValue,height:w.doubleValue) : NSSize(width:w.doubleValue,height:h.doubleValue)
    }
    static func body(_ string:String, rect:NSRect, size:Double) { text(string,rect:rect.insetBy(dx:15,dy:10),size:size,color:NSColor(calibratedRed:0.29,green:0.22,blue:0.13,alpha:1),bold:false,center:false,shrink:false) }
    static func text(_ string:String, rect:NSRect, size:Double, color:NSColor, bold:Bool, center:Bool, shrink:Bool, italic:Bool = false) {
        guard !string.isEmpty else { return }
        let para = NSMutableParagraphStyle(); para.alignment = center ? .center : .left; para.lineBreakMode = .byWordWrapping
        var s = CGFloat(size)
        func attrs(_ s:CGFloat) -> [NSAttributedString.Key:Any] {
            let font = NSFont(name:bold ? "Georgia-Bold" : (italic ? "Georgia-Italic" : "Georgia"),size:s) ?? NSFont.systemFont(ofSize:s,weight:bold ? .bold : .regular)
            return [.font:font, .foregroundColor:color, .paragraphStyle:para]
        }
        if shrink {
            while s > 14 {
                let box = (string as NSString).boundingRect(with:NSSize(width:rect.width,height:10000),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(s))
                if box.height <= rect.height { break }; s -= 1
            }
        }
        NSGraphicsContext.current?.cgContext.saveGState(); NSBezierPath(rect:rect).addClip()
        (string as NSString).draw(with:rect,options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(s))
        NSGraphicsContext.current?.cgContext.restoreGState()
    }
}

final class TextFieldMemory: ObservableObject {
    var fields: [String: NSTextField] = [:]
    var selections: [String: NSRange] = [:]
    static func inserting(_ insertion: String, into text: String, at selection: NSRange?) -> (String, NSRange) {
        let old = text as NSString
        let range = selection ?? NSRange(location:old.length, length:0)
        let start = range.location == NSNotFound ? old.length : max(0,min(range.location,old.length))
        let length = max(0,min(range.length,old.length-start))
        let result = old.replacingCharacters(in:NSRange(location:start,length:length),with:insertion)
        return (result, NSRange(location:start+(insertion as NSString).length,length:0))
    }
    func paste(into text: Binding<String>, key: String, pasteboard: NSPasteboard = .general, status: (String) -> Void) {
        guard let insertion = pasteboard.string(forType:.string), !insertion.isEmpty else { status("В буфере обмена нет текста."); return }
        let field = fields[key]
        let selected = field?.currentEditor()?.selectedRange ?? selections[key]
        let (value, caret) = Self.inserting(insertion,into:text.wrappedValue,at:selected)
        text.wrappedValue = value; selections[key] = caret
        if let field = field { DispatchQueue.main.async { field.window?.makeFirstResponder(field); field.currentEditor()?.selectedRange = caret } }
        status("Текст вставлен из буфера обмена.")
    }
    func copy(_ text: String, pasteboard: NSPasteboard = .general, status: (String) -> Void) {
        guard !text.isEmpty else { return }
        pasteboard.clearContents(); pasteboard.setString(text,forType:.string)
        status("Текст скопирован в буфер обмена.")
    }
}
struct EditableTitleField: NSViewRepresentable {
    let placeholder: String
    let key: String
    @Binding var text: String
    @ObservedObject var memory: TextFieldMemory
    func makeCoordinator() -> Coordinator { Coordinator(owner:self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string:text)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.setAccessibilityLabel(placeholder)
        memory.fields[key] = field
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.owner = self
        if field.stringValue != text { field.stringValue = text }
        if let editor = field.currentEditor(), editor.string != text { editor.string = text }
        memory.fields[key] = field
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var owner: EditableTitleField
        init(owner:EditableTitleField) { self.owner = owner }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            owner.text = field.stringValue
            if let editor = field.currentEditor() { owner.memory.selections[owner.key] = editor.selectedRange }
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            if let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView { owner.memory.selections[owner.key] = editor.selectedRange() }
        }
    }
}

struct SelectedPhoto: Identifiable { let id:Int }
final class EditorUIState: ObservableObject {
    @Published var selectedPhoto: SelectedPhoto?
    @Published var dragStart: PhotoTransform?
}
struct ContentView: View {
    @StateObject private var editorUI = EditorUIState()
    @StateObject var store = Store()
    @StateObject var textFields = TextFieldMemory()
    let layouts = ["Одна фотография", "Две фотографии", "Три фотографии с наложением", "Только текст", "Фото слева, текст справа", "Фото сверху, текст снизу"]
    let modes = ["Растянуть", "Обрезать края", "Показать целиком", "Исходный размер (1:1)"]
    var card: Binding<Card> { Binding(get: { store.project.cards[min(max(store.selected,0),store.project.cards.count-1)] }, set: { store.project.cards[min(max(store.selected,0),store.project.cards.count-1)] = $0 }) }
    var body: some View {
        HStack(spacing:0) {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Text("Карточки A6").font(.title.bold())
                    Text("Редактор листа A4").foregroundStyle(.secondary)
                    HStack { Button("Открыть проект") { store.openProject() }; Button("Сохранить проект") { _ = store.saveProject() } }
                    HStack {
                        Button("↶ Отменить") { store.undo() }.disabled(!store.canUndo).keyboardShortcut("z", modifiers:.command)
                        Button("↷ Повторить") { store.redo() }.disabled(!store.canRedo).keyboardShortcut("z", modifiers:[.command,.shift])
                    }
                    Divider()
                    Picker("Лист A4",selection:$store.project.sheetMode) {
                        Text("4 карточки A6").tag(SheetMode.portrait)
                        Text("2 карточки A5").tag(SheetMode.landscape)
                    }.pickerStyle(.segmented)
                    Text(store.project.sheetMode == .landscape ? "Альбомный A4: две карточки на листе." : "Книжный A4: четыре карточки на листе.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        ForEach(Array(store.project.cards.enumerated()), id:\.element.id) { i, _ in
                            Button("\(i+1)") { store.selected = i }.buttonStyle(.borderedProminent).tint(store.selected == i ? .accentColor : .gray)
                        }
                        Button("+") { store.add() }.help("Добавить карточку")
                    }
                    HStack { Button("←") { store.move(-1) }.disabled(store.selected == 0); Button("→") { store.move(1) }.disabled(store.selected >= store.project.cards.count-1); Button("Удалить") { store.remove() }; Spacer() }
                    Text("Карточка \(store.selected+1)").font(.headline)
                    HStack(spacing:4) {
                        Toggle("Показывать блок «К занятию»", isOn:card.showIntro).fixedSize()
                        Spacer(minLength:4)
                        if store.project.cards.count > 1 {
                            Text("Из:").font(.caption).foregroundStyle(.secondary).help("Перенести три строки и их размеры из другой карточки")
                            ForEach(Array(store.project.cards.indices),id:\.self) { i in
                                if i != store.selected {
                                    Button("\(i+1)") { store.copyHeadings(from:i) }
                                        .controlSize(.mini).frame(minWidth:21)
                                        .help("Перенести три строки и их размеры из карточки \(i+1)")
                                        .accessibilityLabel("Перенести строки из карточки \(i+1)")
                                }
                            }
                        }
                    }
                    if card.wrappedValue.showIntro {
                        titleField("К занятию", key:"intro", text:card.intro)
                        sizeSlider("Размер первой строки", value:card.introSize, range:18...65)
                        titleField("Название занятия", key:"topic", text:card.topic)
                        sizeSlider("Размер названия занятия", value:card.topicSize, range:18...70)
                    }
                    titleField("Заголовок задания", key:"heading", text:card.heading)
                    HStack { Text("Размер заголовка"); Slider(value:card.headingSize,in:25...85,step:1); Text("\(Int(card.wrappedValue.headingSize))").monospacedDigit().frame(width:25) }
                    Picker("Содержимое",selection:card.layout) { ForEach(layouts,id:\.self) { Text($0) } }
                    if card.wrappedValue.layout != "Только текст" { imageControls(1) }
                    if card.wrappedValue.layout == "Две фотографии" {
                        Picker("Расположение фото", selection:card.photoArrangement) {
                            Text("Рядом").tag("Рядом")
                            Text("Сверху вниз").tag("Сверху вниз")
                        }.pickerStyle(.segmented)
                        imageControls(2)
                    }
                    if card.wrappedValue.layout == "Три фотографии с наложением" {
                        imageControls(2)
                        imageControls(3)
                        Text("Фотографии идут слева направо; каждая следующая немного перекрывает предыдущую.").font(.caption).foregroundStyle(.secondary)
                    }
                    if ["Только текст","Фото слева, текст справа","Фото сверху, текст снизу"].contains(card.wrappedValue.layout) {
                        Text("Текст карточки").font(.headline)
                        TextEditor(text:card.text).font(.system(size:14)).frame(height:120).border(.quaternary)
                        HStack { Text("Размер текста"); Slider(value:card.textSize,in:18...80,step:1); Text("\(Int(card.wrappedValue.textSize))").monospacedDigit().frame(width:25) }
                        Text("Если текст не помещается, уменьшите размер шрифта.").font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text("Поля для печати").font(.headline)
                    HStack { Slider(value:$store.project.marginMM,in:0...15,step:0.5); Text(String(format:"%.1f мм",store.project.marginMM)).frame(width:65) }
                    let horizontal = store.project.sheetMode == .landscape
                    let g = Renderer.geometry(mode:store.project.sheetMode,width:horizontal ? 3508 : 2480,margin:store.project.marginMM)
                    let mmPerPixel:CGFloat = horizontal ? 297/3508 : 210/2480
                    Text(String(format:"Размер карточки на листе: %.1f × %.1f мм",g.cardW*mmPerPixel,g.cardH*mmPerPixel)).font(.caption).foregroundStyle(.secondary)
                    Text(horizontal ? "Точный A5 заполняет лист до краёв; для принтера настройте поля." : "Точный A6 заполняет лист до краёв; для принтера настройте поля.").font(.caption).foregroundStyle(.secondary)
                    Button(store.project.pageCount > 1 ? "Экспорт PNG с полями — все листы" : "Экспорт PNG с полями") { store.export(margin:store.project.marginMM) }.buttonStyle(.borderedProminent)
                    Button(horizontal ? "Экспорт PNG: точный A5 без полей" : "Экспорт PNG: точный A6 без полей") { store.export(margin:0) }
                    Text(store.status).font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.frame(minWidth:390,idealWidth:420,maxWidth:470)
            Divider()
            VStack(spacing:8) {
                HStack { Text("Предпросмотр A4").font(.headline); Spacer(); Text(store.project.marginMM == 0 ? "Без полей" : String(format:"Поля: %.1f мм",store.project.marginMM)).foregroundStyle(.secondary) }
                if store.project.sheetMode == .landscape {
                    HStack {
                        let page = store.project.page(for:store.selected)
                        Button("←") { store.selectPage(page-1) }.disabled(page == 0)
                        Text("Лист \(page+1) из \(store.project.pageCount)").monospacedDigit()
                        Button("→") { store.selectPage(page+1) }.disabled(page+1 >= store.project.pageCount)
                        Spacer()
                        Text("Карточки \(page*2+1)–\(min(page*2+2,store.project.cards.count))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                GeometryReader { geometry in
                    if let image = store.preview {
                        Image(nsImage:image).resizable().interpolation(.high).aspectRatio(contentMode:.fit).frame(width:geometry.size.width,height:geometry.size.height).shadow(radius:5)
                    }
                }
                Text(store.project.sheetMode == .landscape ? "Две карточки слева направо на каждом листе" : "Расположение: слева направо, сверху вниз").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(minWidth:400,maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.controlBackgroundColor))
        }
        .frame(minWidth:850,minHeight:720)
        .onChange(of:store.project) { _ in store.updatePreview() }
        .onChange(of:store.selected) { _ in textFields.selections.removeAll(); store.updatePreview() }
        .sheet(item:$editorUI.selectedPhoto) { selection in PhotoEditor(card:card,store:store,number:selection.id) }
    }
    func titleField(_ placeholder: String, key: String, text: Binding<String>) -> some View {
        HStack(spacing:5) {
            EditableTitleField(placeholder:placeholder,key:key,text:text,memory:textFields).frame(height:24)
            Button { textFields.paste(into:text,key:key) { store.status = $0 } } label: { Image(systemName:"doc.on.clipboard") }
                .help("Вставить из буфера обмена").accessibilityLabel("Вставить из буфера: \(placeholder)")
            Button { textFields.copy(text.wrappedValue) { store.status = $0 } } label: { Image(systemName:"doc.on.doc") }
                .help("Копировать текст в буфер обмена").accessibilityLabel("Копировать: \(placeholder)").disabled(text.wrappedValue.isEmpty)
        }
    }
    func sizeSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack { Text(title).font(.caption); Slider(value:value, in:range, step:1); Text("\(Int(value.wrappedValue))").monospacedDigit().frame(width:25) }
    }
    @ViewBuilder func imageControls(_ n:Int) -> some View {
        let data = card.wrappedValue.image(n)
        let mode = n == 1 ? card.imageMode1 : (n == 2 ? card.imageMode2 : card.imageMode3)
        VStack(alignment:.leading,spacing:6) {
            HStack { Button(data == nil ? "Добавить фото \(n)" : "Заменить фото \(n)") { store.chooseImage(n) }; Button("Вставить из буфера") { store.pasteImage(n) }; if data != nil { Button("Удалить") { store.setPhoto(n,nil) } } }
            if data != nil { Button("Кадрировать и переместить фото \(n)…") { editorUI.selectedPhoto = SelectedPhoto(id:n) } }
            Picker("Масштаб",selection:mode) { ForEach(modes,id:\.self) { Text($0) } }
            if mode.wrappedValue == "Исходный размер (1:1)" { Text("При увеличении 100%: 1 пиксель фото = 1 пиксель PNG. Края большого фото обрезаются.").font(.caption).foregroundStyle(.secondary) }
        }
    }

}

struct PhotoEditor: View {
    @Binding var card: Card
    @ObservedObject var store: Store
    let number: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editorUI = EditorUIState()
    let modes = ["Растянуть", "Обрезать края", "Показать целиком", "Исходный размер (1:1)"]
    var edit: Binding<PhotoTransform> { Binding(get:{ card.edit(number) },set:{ card.setEdit(number,$0) }) }
    var mode: Binding<String> { number == 1 ? $card.imageMode1 : (number == 2 ? $card.imageMode2 : $card.imageMode3) }
    func slider(_ title:String, value:Binding<Double>, range:ClosedRange<Double>, format:String) -> some View {
        HStack { Text(title).frame(width:130,alignment:.leading); Slider(value:value,in:range,onEditingChanged:{ editing in if editing { store.beginHistoryGroup() } else { store.endHistoryGroup() } }); Text(String(format:format,value.wrappedValue)).monospacedDigit().frame(width:55,alignment:.trailing) }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Кадрирование фото \(number)").font(.title2.bold()); Spacer(); Button("Готово") { dismiss() }.buttonStyle(.borderedProminent) }
            Text("Перетащите фотографию, чтобы выбрать видимую часть, или используйте ползунки. Если сдвиг недоступен, сначала увеличьте фото или выберите «Обрезать края».").foregroundStyle(.secondary)
            GeometryReader { geo in
                let rect = Renderer.photoRect(card,number)
                let scale = min(geo.size.width/rect.width,geo.size.height/rect.height)
                let w = rect.width*scale, h = rect.height*scale
                if let image = Renderer.photoPreview(card:card,number:number,margin:store.project.marginMM,mode:store.project.sheetMode) {
                    Image(nsImage:image).resizable().interpolation(.high).frame(width:w,height:h)
                        .contentShape(Rectangle()).gesture(DragGesture(minimumDistance:1)
                            .onChanged { value in
                                if editorUI.dragStart == nil { editorUI.dragStart = card.edit(number); store.beginHistoryGroup() }
                                guard let start = editorUI.dragStart, let data = card.image(number), let ns = NSImage(data:data) else { return }
                                let pixelScale = Renderer.exportPixelScale(mode:store.project.sheetMode,margin:store.project.marginMM)
                                let travel = Renderer.photoDestination(data:data,image:ns,rect:NSRect(x:0,y:0,width:rect.width,height:rect.height),mode:card.mode(number),edit:start,pixelScale:pixelScale).1
                                var next = start
                                if travel.width*scale > 0.5 { next.x = min(1,max(-1,start.x+Double(value.translation.width/(travel.width*scale)))) }
                                if travel.height*scale > 0.5 { next.y = min(1,max(-1,start.y+Double(value.translation.height/(travel.height*scale)))) }
                                card.setEdit(number,next)
                            }.onEnded { _ in editorUI.dragStart = nil; store.endHistoryGroup() })
                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                }
            }.frame(height:360).background(Color(nsColor:.controlBackgroundColor)).cornerRadius(8)
            Picker("Режим фото",selection:mode) { ForEach(modes,id:\.self) { Text($0) } }
            slider("Приближение",value:edit.zoom,range:1...4,format:"×%.1f")
            slider("Влево / вправо",value:edit.x,range:-1...1,format:"%.2f")
            slider("Вверх / вниз",value:edit.y,range:-1...1,format:"%.2f")
            HStack { Button("Сбросить кадрирование") { card.setEdit(number,PhotoTransform()) }; Spacer(); Text("Изменения сохраняются в проекте.").font(.caption).foregroundStyle(.secondary) }
        }.padding(20).frame(width:680)
        .onDisappear { store.endHistoryGroup() }
    }
}

struct CardMakerApp: App {
    var body: some Scene { WindowGroup { ContentView() }.defaultSize(width:1150,height:850) }
}
if CommandLine.arguments.contains("--self-test") {
    let s = Store(); var p = s.project; precondition(p.cards.count == 1 && p.cards[0].intro.isEmpty && p.cards[0].topic.isEmpty && p.cards[0].heading.isEmpty); p.cards.append(Card()); p.cards[0].intro = "К занятию"; p.cards[0].topic = "«Рождество Христово»"; p.cards[0].heading = "НАЙДИ 7 ОТЛИЧИЙ"; p.cards[0].layout = "Только текст"; p.cards[0].text = "Пример текста карточки"; p.cards[1].showIntro = false; p.cards[1].layout = "Фото слева, текст справа"; p.cards[1].text = "Текст рядом с фотографией"; if CommandLine.arguments.count > 2 { p.cards[1].image1 = try? Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2])) }; p.cards[1].imageMode1 = "Обрезать края"
    guard let image = Renderer.sheet(project:p,template:s.template,width:840,margin:5), let rep = image.representations.first as? NSBitmapImageRep, let data = rep.representation(using:.png,properties:[:]) else { exit(1) }
    try data.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-selftest.png"))
    let encoded = try JSONEncoder().encode(p)
    let decoded = try JSONDecoder().decode(Project.self, from:encoded); guard decoded == p else { exit(2) }
    var json = try JSONSerialization.jsonObject(with:encoded) as! [String:Any]
    var oldCards = json["cards"] as! [[String:Any]]
    for i in oldCards.indices { oldCards[i].removeValue(forKey:"introSize"); oldCards[i].removeValue(forKey:"topicSize"); oldCards[i].removeValue(forKey:"photoArrangement"); for k in ["image3","imageMode3","photoEdit1","photoEdit2","photoEdit3"] { oldCards[i].removeValue(forKey:k) } }
    json["cards"] = oldCards
    let oldProject = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject:json))
    guard oldProject.cards.count == p.cards.count && oldProject.cards[0].introSize == 31 && oldProject.cards[0].photoArrangement == "Рядом" else { exit(4) }
    if CommandLine.arguments.count > 2, let data = p.cards[1].image1 {
        let board = NSPasteboard(name:NSPasteboard.Name("local.codex.cardmaker.selftest.\(UUID().uuidString)"))
        board.clearContents(); guard board.setData(data, forType:.png), let pasted = Store.imageData(from:board), NSImage(data:pasted) != nil else { exit(5) }
        board.releaseGlobally()
        p.cards[1].layout = "Две фотографии"; p.cards[1].photoArrangement = "Сверху вниз"; p.cards[1].image2 = data
        guard let vertical = Renderer.sheet(project:p,template:s.template,width:840,margin:5), let r = vertical.representations.first as? NSBitmapImageRep, let d = r.representation(using:.png,properties:[:]) else { exit(6) }
        try d.write(to: URL(fileURLWithPath:"/private/tmp/cardmaker-vertical.png"))
        p.cards[1].imageMode1 = "Обрезать края"; p.cards[1].photoEdit1 = PhotoTransform(zoom:1.8,x:0.5,y:-0.3)
        guard let image = Renderer.photoPreview(card:p.cards[1],number:1,margin:5), let bitmap = image.representations.first as? NSBitmapImageRep, let result = bitmap.representation(using:.png,properties:[:]) else { exit(45) }
        try result.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-real-photo-preview.png"))
    }
    // Verify card selection and order changes, including deletion of the last card.
    let model = Store(); let firstID = model.project.cards[0].id
    model.add(); model.add(); model.add()
    guard model.project.cards.count == 4 && model.selected == 3 else { exit(10) }
    let movedID = model.project.cards[3].id; model.move(-1)
    guard model.selected == 2 && model.project.cards[2].id == movedID else { exit(11) }
    model.remove(); guard model.project.cards.count == 3 && !model.project.cards.contains(where:{$0.id == movedID}) else { exit(12) }
    model.remove(); model.remove(); model.remove()
    guard model.project.cards.count == 1 && model.selected == 0 && model.project.cards[0].id != firstID else { exit(13) }
    let repTest = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:100,pixelsHigh:80,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    for y in 0..<80 { for x in 0..<100 { repTest.setColor(NSColor(calibratedRed:1,green:0,blue:1,alpha:1),atX:x,y:y) } }
    let syntheticPNG = repTest.representation(using:.png,properties:[:])!
    let syntheticJPEG = repTest.representation(using:.jpeg,properties:[:])!
    let syntheticTIFF = repTest.representation(using:.tiff,properties:[:])!
    guard Store.validImage(syntheticPNG), Store.validImage(syntheticJPEG), Store.validImage(syntheticTIFF), !Store.validImage(Data("invalid".utf8)), Renderer.pixelDimensions(syntheticPNG, fallback:.zero) == NSSize(width:100,height:80) else { exit(14) }
    let box = URL(fileURLWithPath:"/private/tmp/cardmaker-tests-\(UUID().uuidString)",isDirectory:true)
    try FileManager.default.createDirectory(at:box,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:box) }
    let file = box.appendingPathComponent("тестовое изображение.png"); try syntheticPNG.write(to:file)
    let fileBoard = NSPasteboard(name:NSPasteboard.Name("local.codex.filetest.\(UUID().uuidString)"))
    fileBoard.clearContents(); guard fileBoard.writeObjects([file as NSURL]), Store.imageData(from:fileBoard) == syntheticPNG else { exit(15) }; fileBoard.releaseGlobally()
    let emptyBoard = NSPasteboard(name:NSPasteboard.Name("local.codex.emptytest.\(UUID().uuidString)"))
    emptyBoard.clearContents(); emptyBoard.setString("not an image",forType:.string); guard Store.imageData(from:emptyBoard) == nil else { exit(16) }; emptyBoard.releaseGlobally()
    var testCard = Card(); testCard.showIntro = false; testCard.image1 = syntheticPNG; testCard.image2 = syntheticJPEG
    for layout in ["Одна фотография", "Две фотографии", "Три фотографии с наложением", "Фото слева, текст справа", "Фото сверху, текст снизу", "Только текст"] {
        for arrangement in ["Рядом", "Сверху вниз"] {
            for mode in ["Растянуть", "Обрезать края", "Показать целиком", "Исходный размер (1:1)"] {
                testCard.layout = layout; testCard.photoArrangement = arrangement; testCard.imageMode1 = mode; testCard.imageMode2 = mode
                var proj = Project(); proj.cards = [testCard]
                guard Renderer.sheet(project:proj,template:s.template,width:420,margin:5) != nil else { exit(17) }
            }
        }
    }
    model.project.cards[0] = testCard
    let saveURL = box.appendingPathComponent("моё имя проекта.json")
    try model.saveProject(to:saveURL)
    guard try JSONDecoder().decode(Project.self,from:Data(contentsOf:saveURL)) == model.project else { exit(18) }
    model.project.cards[0].layout = "Одна фотография"; model.project.cards[0].imageMode1 = "Исходный размер (1:1)"
    for margin in [0.0, 5.0] {
        let exportURL = box.appendingPathComponent("имя листа \(margin).png")
        try model.export(to:exportURL,margin:margin)
        guard let bitmap = NSBitmapImageRep(data:try Data(contentsOf:exportURL)), bitmap.pixelsWide == 2480, bitmap.pixelsHigh == 3508 else { exit(19) }
        var minX = bitmap.pixelsWide, maxX = -1, minY = bitmap.pixelsHigh, maxY = -1
        for y in 200..<1600 { for x in 30..<1230 {
            if let c = bitmap.colorAt(x:x,y:y), c.redComponent > 0.9 && c.greenComponent < 0.1 && c.blueComponent > 0.9 { minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y) }
        } }
        guard (99...101).contains(maxX-minX+1), (79...81).contains(maxY-minY+1) else { print("1:1 size mismatch",margin,minX,maxX,minY,maxY); exit(20) }
    }
    let history = Store()
    guard !history.canUndo && !history.canRedo else { exit(22) }
    history.project.cards[0].heading = "Первый заголовок"
    history.project.cards[0].image1 = syntheticPNG
    history.project.cards[0].image1 = syntheticJPEG
    history.undo(); guard history.project.cards[0].image1 == syntheticPNG && history.canRedo else { exit(23) }
    history.redo(); guard history.project.cards[0].image1 == syntheticJPEG else { exit(24) }
    history.undo(); history.undo(); guard history.project.cards[0].image1 == nil else { exit(25) }
    history.undo(); guard history.project.cards[0].heading.isEmpty && !history.canUndo else { exit(26) }
    history.redo(); guard history.project.cards[0].heading == "Первый заголовок" else { exit(27) }
    history.project.cards[0].intro = "Другое изменение"
    guard !history.canRedo else { exit(28) }
    history.add(); let insertedID = history.project.cards[1].id; history.remove(); history.undo()
    guard history.project.cards.count == 2 && history.project.cards[1].id == insertedID else { exit(29) }
    history.redo(); guard history.project.cards.count == 1 else { exit(30) }
    let textBoard = NSPasteboard(name:NSPasteboard.Name("local.codex.texttest.\(UUID().uuidString)"))
    textBoard.clearContents(); textBoard.setString("мир",forType:.string)
    let memory = TextFieldMemory(); var testString = "Привет!"; memory.selections["topic"] = NSRange(location:6,length:1)
    let textBinding = Binding<String>(get:{ testString },set:{ testString = $0 })
    memory.paste(into:textBinding,key:"topic",pasteboard:textBoard) { _ in }
    guard testString == "Приветмир", memory.selections["topic"]?.location == 9 else { exit(31) }
    memory.copy(testString,pasteboard:textBoard) { _ in }
    guard textBoard.string(forType:.string) == "Приветмир" else { exit(32) }
    let emoji = TextFieldMemory.inserting("Х",into:"А😀Б",at:NSRange(location:1,length:2))
    guard emoji.0 == "АХБ" && emoji.1.location == 2 else { exit(33) }
    textBoard.releaseGlobally()
    let transfer = Store(); transfer.project.cards[0].intro = "К занятию"; transfer.project.cards[0].topic = "Название"; transfer.project.cards[0].heading = "Заголовок"
    transfer.project.cards[0].introSize = 25; transfer.project.cards[0].topicSize = 44; transfer.project.cards[0].headingSize = 62; transfer.project.cards[0].showIntro = true
    transfer.add(); transfer.project.cards[1].intro = "Старый текст"; transfer.project.cards[1].showIntro = false; transfer.project.cards[1].text = "Основной текст"; transfer.project.cards[1].image1 = syntheticPNG
    let beforeTransfer = transfer.project.cards[1]; transfer.copyHeadings(from:0)
    let afterTransfer = transfer.project.cards[1]
    guard afterTransfer.intro == "К занятию" && afterTransfer.topic == "Название" && afterTransfer.heading == "Заголовок" && afterTransfer.introSize == 25 && afterTransfer.topicSize == 44 && afterTransfer.headingSize == 62 && !afterTransfer.showIntro && afterTransfer.text == "Основной текст" && afterTransfer.image1 == syntheticPNG else { exit(46) }
    transfer.undo(); guard transfer.project.cards[1] == beforeTransfer else { exit(47) }
    transfer.redo(); guard transfer.project.cards[1] == afterTransfer else { exit(48) }
    transfer.copyHeadings(from:1); guard transfer.project.cards[1] == afterTransfer else { exit(49) }
    print("copy three heading fields and sizes from chosen card, preserve content, undo/redo: OK")
    print("undo/redo: text, image replacement, deletion, redo invalidation; clipboard and selection: OK")
    // Crop geometry, grouping, and the overlap order are the same in preview and export.
    func colorImage(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:90,pixelsHigh:120,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        for y in 0..<120 { for x in 0..<90 { rep.setColor(NSColor(calibratedRed:r,green:g,blue:b,alpha:1),atX:x,y:y) } }
        return rep.representation(using:.png,properties:[:])!
    }
    let red = colorImage(1,0,0), green = colorImage(0,1,0), blue = colorImage(0,0,1)
    var triple = Card(); triple.showIntro = false; triple.layout = "Три фотографии с наложением"; triple.image1 = red; triple.image2 = green; triple.image3 = blue
    let r1=Renderer.photoRect(triple,1), r2=Renderer.photoRect(triple,2), r3=Renderer.photoRect(triple,3)
    guard r1.intersects(r2), r2.intersects(r3), r1.minX < r2.minX && r2.minX < r3.minX else { exit(34) }
    var tripleProject=Project(); tripleProject.cards=[triple]; tripleProject.marginMM=0
    guard let rendered = Renderer.sheet(project:tripleProject,template:s.template,width:840,margin:0), let pixels = rendered.representations.first as? NSBitmapImageRep else { exit(35) }
    func sample(_ x:CGFloat,_ y:CGFloat) -> NSColor? { pixels.colorAt(x:Int(x*420/Renderer.cw),y:Int(y*420/Renderer.cw)) }
    let cy = r2.midY
    guard let left = sample(r1.minX+r1.width*0.2,cy), left.redComponent > 0.9 && left.greenComponent < 0.1,
          let middle = sample((r2.minX+r1.maxX)/2,cy), middle.greenComponent > 0.9 && middle.redComponent < 0.1,
          let right = sample((r3.minX+r2.maxX)/2,cy), right.blueComponent > 0.9 && right.greenComponent < 0.1 else { exit(36) }
    if let data = pixels.representation(using:.png,properties:[:]) { try data.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-three-photos.png")) }
    guard let image=NSImage(data:red) else { exit(37) }
    let rect=NSRect(x:0,y:0,width:240,height:180)
    let leftCrop=Renderer.photoDestination(data:red,image:image,rect:rect,mode:"Обрезать края",edit:PhotoTransform(zoom:2,x:-1,y:0),pixelScale:1)
    let rightCrop=Renderer.photoDestination(data:red,image:image,rect:rect,mode:"Обрезать края",edit:PhotoTransform(zoom:2,x:1,y:0),pixelScale:1)
    guard leftCrop.0.width == rightCrop.0.width && leftCrop.0.minX < rightCrop.0.minX && leftCrop.1.width > 0 else { exit(38) }
    triple.photoEdit2=PhotoTransform(zoom:2,x:0.75,y:-0.5); tripleProject.cards=[triple]
    guard let photoPreview=Renderer.photoPreview(card:triple,number:2,margin:0), let pr=photoPreview.representations.first as? NSBitmapImageRep, let prev=pr.representation(using:.png,properties:[:]) else { exit(39) }
    try prev.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-photo-editor.png"))
    let editHistory=Store(); editHistory.setPhoto(1,red); editHistory.beginHistoryGroup(); editHistory.project.cards[0].photoEdit1.zoom=1.5; editHistory.project.cards[0].photoEdit1.zoom=2.0; editHistory.project.cards[0].photoEdit1.x=0.7; editHistory.endHistoryGroup()
    editHistory.undo(); guard editHistory.project.cards[0].photoEdit1 == PhotoTransform() && editHistory.project.cards[0].image1 == red else { exit(40) }
    editHistory.redo(); guard editHistory.project.cards[0].photoEdit1.zoom == 2.0 && editHistory.project.cards[0].photoEdit1.x == 0.7 else { exit(41) }
    editHistory.setPhoto(1,blue); guard editHistory.project.cards[0].photoEdit1 == PhotoTransform() else { exit(42) }
    editHistory.undo(); guard editHistory.project.cards[0].image1 == red && editHistory.project.cards[0].photoEdit1.zoom == 2.0 else { exit(43) }
    let extendedURL=box.appendingPathComponent("новый формат.json"); editHistory.project=tripleProject; try editHistory.saveProject(to:extendedURL)
    let restored=try JSONDecoder().decode(Project.self,from:Data(contentsOf:extendedURL))
    guard restored.version == 2 && restored.cards[0].image3 == blue && restored.cards[0].photoEdit2 == triple.photoEdit2 else { exit(44) }
    print("photo crop/zoom geometry, layered order, preview, one-step undo, image replacement, project versioning: OK")
    // A legacy four-card project becomes two landscape A4 pages without losing cards.
    var legacy = Project(); legacy.cards = [Card(),Card(),Card(),Card()]
    let colors = [red,green,blue,colorImage(1,1,0)]
    for i in 0..<4 { legacy.cards[i].showIntro = false; legacy.cards[i].image1 = colors[i]; legacy.cards[i].heading = "Карточка \(i+1)" }
    let legacyJSON = try JSONEncoder().encode(legacy)
    var legacyDict = try JSONSerialization.jsonObject(with:legacyJSON) as! [String:Any]; legacyDict.removeValue(forKey:"sheetMode")
    let legacyURL = box.appendingPathComponent("старый проект.json"); try JSONSerialization.data(withJSONObject:legacyDict).write(to:legacyURL)
    let imported = try model.loadProject(from:legacyURL,keepingLegacyMode:.landscape)
    guard imported.sheetMode == .landscape && imported.pageCount == 2 && imported.cards.count == 4 && imported.cards.map(\.id) == legacy.cards.map(\.id) && imported.cards.map(\.image1) == legacy.cards.map(\.image1) else { exit(50) }
    guard try model.loadProject(from:legacyURL,keepingLegacyMode:.portrait).sheetMode == .portrait else { exit(51) }
    let landscapeGeometry = Renderer.geometry(mode:.landscape,width:1188,margin:0)
    guard Int(landscapeGeometry.height) == 840, abs(landscapeGeometry.cardW-594)<0.01, abs(landscapeGeometry.cardH-840)<0.2 else { exit(52) }
    for page in 0..<2 {
        guard let sheet = Renderer.sheet(project:imported,template:s.template,width:1188,margin:0,page:page), let pix = sheet.representations.first as? NSBitmapImageRep, pix.pixelsWide == 1188, pix.pixelsHigh == 840 else { exit(53) }
        let y=Int(landscapeGeometry.startY+landscapeGeometry.cardH*0.54), x1=Int(landscapeGeometry.startX+landscapeGeometry.cardW*0.5), x2=Int(landscapeGeometry.startX+landscapeGeometry.cardW*1.5)
        guard let l=pix.colorAt(x:x1,y:y), let r=pix.colorAt(x:x2,y:y) else { exit(54) }
        if page == 0 { guard l.redComponent>0.9 && l.greenComponent<0.1 && r.greenComponent>0.9 && r.redComponent<0.1 else { exit(55) } }
        else { guard l.blueComponent>0.9 && l.redComponent<0.1 && r.redComponent>0.9 && r.greenComponent>0.9 && r.blueComponent<0.1 else { exit(56) } }
        if let data = pix.representation(using:.png,properties:[:]) { try data.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-landscape-\(page+1).png")) }
    }
    guard Renderer.sheet(project:imported,template:s.template,width:1188,margin:0,page:2) == nil else { exit(57) }
    let padded = Renderer.geometry(mode:.landscape,width:3508,margin:5)
    let pxPerMM=3508.0/297.0
    guard padded.startX/pxPerMM >= 4.99 && padded.startY/pxPerMM >= 4.99 else { exit(58) }
    guard let nativeImage = NSImage(data:syntheticPNG) else { exit(59) }
    let scale = Renderer.exportPixelScale(mode:.landscape,margin:5)
    let nativeRect = Renderer.photoDestination(data:syntheticPNG,image:nativeImage,rect:NSRect(x:0,y:0,width:600,height:700),mode:"Исходный размер (1:1)",edit:PhotoTransform(),pixelScale:scale).0
    guard abs(nativeRect.width*padded.cardW/Renderer.cw-100)<0.001 && abs(nativeRect.height*padded.cardW/Renderer.cw-80)<0.001 else { exit(60) }
    let landscapeStore = Store(); landscapeStore.project=imported; landscapeStore.selected=0; landscapeStore.selectPage(1); guard landscapeStore.selected == 2 && landscapeStore.preview != nil else { exit(61) }
    landscapeStore.selectPage(0); guard landscapeStore.selected == 0 else { exit(62) }
    let multiBase=box.appendingPathComponent("Две страницы.png"); try landscapeStore.exportAll(to:multiBase,margin:5)
    let urls=landscapeStore.exportURLs(base:multiBase,count:2)
    guard urls.map(\.lastPathComponent) == ["Две страницы-1.png","Две страницы-2.png"] else { exit(63) }
    for url in urls { guard let img=NSBitmapImageRep(data:try Data(contentsOf:url)),img.pixelsWide == 3508 && img.pixelsHigh == 2480 else { exit(64) } }
    let newProjectURL=box.appendingPathComponent("альбомный проект.json"); try landscapeStore.saveProject(to:newProjectURL)
    let savedLandscape=try landscapeStore.loadProject(from:newProjectURL,keepingLegacyMode:.portrait)
    guard savedLandscape.version == 3 && savedLandscape.sheetMode == .landscape && savedLandscape.cards.count == 4 && savedLandscape.pageCount == 2 else { exit(65) }
    print("landscape A4: legacy import, card order, A5, margins, 1:1 pixels, two PNG files, v3 project: OK")
    let panel = model.makeSavePanel(title:"Test",name:"своё имя.png",type:.png)
    guard panel.nameFieldStringValue == "своё имя.png" && panel.canCreateDirectories && panel.allowedContentTypes.contains(.png) else { exit(21) }
    print("card order, photo formats, layouts, clipboard, project save, named PNG export, 1:1 pixels, save panel: OK")
    guard let full = Renderer.sheet(project:p,template:s.template,width:2480,margin:5), let png = full.pngData() else { exit(3) }
    try png.write(to:URL(fileURLWithPath:"/private/tmp/cardmaker-fulltest.png")); print("self-test ok \(rep.pixelsWide)x\(rep.pixelsHigh); project round trip; PNG 2480x3508")
} else { CardMakerApp.main() }
