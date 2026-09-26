import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
void main() {
 for(final f in Directory('lib/presentation').listSync(recursive:true).whereType<File>().where((f)=>f.path.endsWith('.dart'))) {
  var s=f.readAsStringSync();final changes=<int,(int,String)>{};
  parseString(content:s).unit.accept(Boundaries(changes));
  for(final p in changes.keys.toList()..sort((a,b)=>b.compareTo(a)))s=s.replaceRange(p,p+changes[p]!.$1,changes[p]!.$2);
  if(changes.isNotEmpty && !s.contains('core/localization/app_localizations.dart'))s="import 'package:car_rent_manager/core/localization/app_localizations.dart';\n$s";
  f.writeAsStringSync(s);
 }
}
class Boundaries extends RecursiveAstVisitor<void> {
 Boundaries(this.changes);
 final Map<int,(int,String)> changes;
 @override void visitMethodInvocation(MethodInvocation n) {
  if(n.methodName.name == 'AppText' && n.target == null && n.argumentList.arguments.isNotEmpty) {
    final a=n.argumentList.arguments.first.toSource();
    if (RegExp(r'\.(fullName|firstName|lastName|registrationNumber|contractNumber|phone|email|cin|licenseNumber|notes)\b').hasMatch(a) && !a.contains('AppCopy.') || a.contains('.brand}') || a.contains('lookups.vehicleName(') || a=='message.text') {
      changes[n.methodName.offset]=(n.methodName.length,'Text');
    }
  }
  final replacement={'formatMad':'context.money','formatKm':'context.distance'}[n.methodName.name];
  if(replacement!=null && n.target==null)changes[n.methodName.offset]=(n.methodName.length,replacement);
  super.visitMethodInvocation(n);
 }
 @override void visitInstanceCreationExpression(InstanceCreationExpression n) {
  if(n.constructorName.type.name2.lexeme=='AppText' && n.argumentList.arguments.isNotEmpty) {
    final a=n.argumentList.arguments.first.toSource();
    if(RegExp(r'\.(fullName|firstName|lastName|registrationNumber|contractNumber|phone|email|cin|licenseNumber|notes)\b').hasMatch(a) && !a.contains('AppCopy.') && !a.contains('context.') ||
      a.contains('.brand}') || a=='message.text' || a=='client.fullName' || a=='_deviceId!') {
      changes[n.constructorName.offset]=(n.constructorName.length,'Text');
    }
  }
  super.visitInstanceCreationExpression(n);
 }
}
