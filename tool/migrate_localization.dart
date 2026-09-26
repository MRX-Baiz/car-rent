import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

String normalize(String s) => s.trim().replaceAll("'", '’').replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'[.。]+$'), '');
void main() {
  final keys = Map<String,String>.from(jsonDecode(File('lib/l10n/legacy_sources.json').readAsStringSync()));
  for(final f in Directory('lib/presentation').listSync(recursive:true).whereType<File>().where((f)=>f.path.endsWith('.dart') && !f.path.contains('/providers/'))) {
    final s=f.readAsStringSync(); final changes=<int, (int,String)>{};
    parseString(content:s).unit.accept(Migrate(keys,changes));
    if(changes.isEmpty) continue;
    var out=s;
    for(final offset in changes.keys.toList()..sort((a,b)=>b.compareTo(a))) {
      final c=changes[offset]!; out=out.replaceRange(offset,offset+c.$1,c.$2);
    }
    if(!s.contains('core/localization/app_localizations.dart')) out="import 'package:car_rent_manager/core/localization/app_localizations.dart';\n$out";
    f.writeAsStringSync(out);
  }
}
class Migrate extends RecursiveAstVisitor<void> {
  Migrate(this.keys,this.changes);
  final Map<String,String> keys;
  final Map<int,(int,String)> changes;
  void replace(StringLiteral n) {
    if(n.parent is AdjacentStrings || n.stringValue==null) return;
    final key=keys[normalize(n.stringValue!)]; if(key==null) return;
    // Equality checks compare domain values, not localized UI messages.
    if(n.parent is BinaryExpression || n.parent is SwitchCase || n.parent is ConstantPattern) return;
    AstNode? parent=n.parent;
    while(parent!=null) {
      if(parent is MethodInvocation && ['replaceFirst','replaceAll','contains','startsWith','endsWith','split','toLowerCase'].contains(parent.methodName.name)) return;
      parent=parent.parent;
    }
    var expr='AppCopy.$key';
    parent=n.parent;
    while(parent!=null) {
      if(parent is MethodInvocation && parent.methodName.name=='tr') break;
      if(parent is NamedExpression && ['labelText','hintText','helperText','tooltip','helpText','semanticsLabel','text','subject'].contains(parent.name.label.name) || parent is InstanceCreationExpression && parent.constructorName.type.name2.lexeme=='Text') {
        expr='context.tr($expr)';
        AstNode? a=n.parent;
        while(a!=null) {
          if(a is InstanceCreationExpression && a.keyword?.lexeme=='const') changes[a.keyword!.offset]=(a.keyword!.length,'');
          if(a is ListLiteral && a.constKeyword!=null) changes[a.constKeyword!.offset]=(a.constKeyword!.length,'');
          a=a.parent;
        }
        break;
      }
      parent=parent.parent;
    }
    changes[n.offset]=(n.length,expr);
  }
  @override void visitSimpleStringLiteral(SimpleStringLiteral node) => replace(node);
  @override void visitAdjacentStrings(AdjacentStrings node) => replace(node);
}
