import 'dart:io';
// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';

void main() {
  runApp(const MyApp()); //funcion principal
}

class MyApp extends StatelessWidget { // funcion que se llama osea myapp
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Duplicate Finder',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FileScannerPage(),
    );
  }
}

class FileScannerPage extends StatefulWidget {
  const FileScannerPage({super.key});

  @override
  _FileScannerPageState createState() => _FileScannerPageState();
}

class _FileScannerPageState extends State<FileScannerPage> {
  List<FileSystemEntity> files = [];
  String message = '';
  bool isLoading = false;

  Future<void> solicitarPermisos() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isDenied) {
      setState(() {
        message = "❌ Permiso denegado para acceder a archivos.";
      });
      return;
    }
    setState(() {
      message = "✅ Permiso de almacenamiento concedido";
    });
  }

  Future<String> _getFileHash(File file) async {
    var input = file.openRead();
    var hash = await md5.bind(input).first;
    return hash.toString();
  }

  Future<void> moveDuplicateFile(File duplicate, Directory newFolder) async {
    if (!newFolder.existsSync()) {
      newFolder.createSync(recursive: true);
    }
    String newPath = '${newFolder.path}/${duplicate.uri.pathSegments.last}';
    File duplicateFile = File(newPath);
    if (!duplicateFile.existsSync()) {
      try {
        await duplicate.copy(newPath);
        await duplicate.delete();
        setState(() {
          message = "✅ Archivo duplicado movido: ${duplicate.path}";
        });
      } catch (e) {
        setState(() {
          message = "❌ Error al mover archivo: $e";
        });
      }
    } else {
      setState(() {
        message = "⚠️ El archivo ya existe en la carpeta de duplicados.";
      });
    }
  }

  Future<void> _pickFolder() async {
    await solicitarPermisos(); // solisita permisos de usuario
    if (message != "✅ Permiso de almacenamiento concedido") return;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(); // pérmite seleccionar carpeta
    if (selectedDirectory != null) {
      setState(() {
        isLoading = true;
        message = "🔍 Escaneando archivos...";
      }); // se escaneas los arhibus buscando los duplicados

      Directory dir = Directory(selectedDirectory);
      List<FileSystemEntity> fileList =
          dir.listSync(recursive: true).whereType<File>().toList();
      Map<String, List<File>> fileMap = {};

      for (var entity in fileList) {
        if (entity is File) {
          // Asegura que solo se procesen archivos
          try {
            String fileHash = await _getFileHash(entity);
            print("📄 Archivo: ${entity.path} → Hash: $fileHash");

            if (fileMap.containsKey(fileHash)) {
              fileMap[fileHash]?.add(entity);
            } else {
              fileMap[fileHash] = [entity];
            }
          } catch (e) {
            print("⚠️ Error al leer archivo ${entity.path}: $e");
          }
        }
      }

      List<File> duplicates = [];
      fileMap.forEach((key, value) {
        if (value.length > 1) {
          duplicates.addAll(value.sublist(1));
        }
      });

      String newFolderPath = '${selectedDirectory}/Duplicados';
      Directory newFolder = Directory(newFolderPath);
      if (!newFolder.existsSync()) {
        newFolder.createSync(recursive: true);
      }

      for (var duplicate in duplicates) {
        await moveDuplicateFile(duplicate, newFolder);
      }

      setState(() {
        files = duplicates;
        message = "✅ Escaneo finalizado. Archivos duplicados movidos.";
        isLoading = false;
      });
    } else {
      setState(() {
        message = "⚠️ No se seleccionó ninguna carpeta.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar Archivos Duplicados")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickFolder,
            child: const Text("Seleccionar Carpeta"),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(files[index].path.split('/').last),
                      subtitle: Text(files[index].path),
                    );
                  },
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
