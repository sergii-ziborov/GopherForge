// Exports public lesson material without hidden tests, verified answers or progress.
import Foundation
struct GoSourceSnapshot { let files: [String:String]; let packagePattern: String; let entryFile: String; let workspaceReuseKey: String }
enum GoLanguage { static func module(_ name:String)->String { "module \(name)\n\ngo 1.27\n" } }
@main struct Export {
 static func main() throws {
  var units:[[String:Any]]=[]
  for unit in GoCourseCatalog.units {
   var lessons:[[String:Any]]=[]
   for l in unit.lessons {
    var d:[String:Any]=["id":l.id,"title":l.title,"objective":l.objective,"explanation":l.explanation,"tags":l.conceptTags]
    switch l.task {
     case .reading:
      d["kind"]="reading"
      if let reading = ReadingLessonCatalog.reading(for: l.id) {
       d["reading"] = [
        "sections": reading.sections.map { section -> [String:Any] in
         var item:[String:Any] = ["title":section.title,"body":section.body]
         if let code=section.code { item["code"]=code }
         if let language=section.language { item["language"]=language }
         if let walkthrough=section.walkthrough { item["walkthrough"]=walkthrough }
         return item
        },
        "takeaway": reading.takeaway,
        "references": reading.references.map(\.absoluteString)
       ]
      }
     case let .compile(starter,test): d["kind"]="compile";d["source"]=starter;_ = test
     case let .predict(source,question,answer): d["kind"]="predict";d["source"]=source;d["question"]=question;_ = answer
     case let .guidedTyping(target):d["kind"]="read";d["source"]=target
     case let .fillGaps(template,blanks):d["kind"]="gaps";d["source"]=template;d["blanks"]=blanks
    }
    lessons.append(d)
   }
   units.append(["id":unit.id,"title":unit.title,"summary":unit.summary,"translationNote":unit.translationNote,"lessons":lessons])
  }
  let data=try JSONSerialization.data(withJSONObject:units,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
  print(String(data:data,encoding:.utf8)!)
 }
}
