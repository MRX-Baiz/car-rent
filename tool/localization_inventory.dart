import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main() {
  final catalog = parseString(content: File('lib/core/localization/app_localizations.dart').readAsStringSync()).unit;
  final maps = <String, Map<String, String>>{};
  catalog.accept(_Maps(maps));
  File('/tmp/carrent-catalog.json').writeAsStringSync(jsonEncode(maps));
  final entries = <Map<String, Object?>>[];
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('/localization/'))) {
    parseString(content: file.readAsStringSync()).unit.accept(_Strings(file.path, entries));
  }
  File('/tmp/carrent-strings.json').writeAsStringSync(jsonEncode(entries));
}
class _Maps extends RecursiveAstVisitor<void> {
  _Maps(this.maps);
  final Map<String, Map<String,String>> maps;
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == '_english' || node.name.lexeme == '_arabic') {
      maps[node.name.lexeme] = {
        for (final e in (node.initializer as SetOrMapLiteral).elements.whereType<MapLiteralEntry>())
          (e.key as StringLiteral).stringValue!: (e.value as StringLiteral).stringValue!
      };
    }
    super.visitVariableDeclaration(node);
  }
}
class _Strings extends RecursiveAstVisitor<void> {
  _Strings(this.path, this.entries);
  final String path;
  final List<Map<String,Object?>> entries;
  List<Map<String,String>> parts(StringLiteral node) {
    if (node is SimpleStringLiteral) return [{'text':node.value}];
    if (node is AdjacentStrings) return node.strings.expand(parts).toList();
    if (node is StringInterpolation) return node.elements.map((e) => e is InterpolationString ? {'text':e.value} : {'expression':(e as InterpolationExpression).expression.toSource()}).toList();
    return [];
  }
  void add(StringLiteral node) {
    if (node.parent is AdjacentStrings || node.parent is Directive || node.parent is UriBasedDirective) return;
    entries.add({'path':path,'offset':node.offset,'length':node.length,'value':node.stringValue,'code':node.toSource(),'parent':node.parent.runtimeType.toString(),'parts':parts(node)});
  }
  @override void visitSimpleStringLiteral(SimpleStringLiteral node) => add(node);
  @override void visitAdjacentStrings(AdjacentStrings node) => add(node);
  @override void visitStringInterpolation(StringInterpolation node) => add(node);
}
