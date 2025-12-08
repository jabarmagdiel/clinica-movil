import 'package:flutter/material.dart';
import '../../api.dart';

/// Pantalla para crear o editar una valoración de un médico
class PantallaCrearValoracion extends StatefulWidget {
  final int medicoId;
  final String medicoNombre;
  final int pacienteId;
  final int? valoracionId; // Si existe, es edición
  final int? calificacionInicial;
  final String? comentarioInicial;

  const PantallaCrearValoracion({
    Key? key,
    required this.medicoId,
    required this.medicoNombre,
    required this.pacienteId,
    this.valoracionId,
    this.calificacionInicial,
    this.comentarioInicial,
  }) : super(key: key);

  @override
  State<PantallaCrearValoracion> createState() => _PantallaCrearValoracionState();
}

class _PantallaCrearValoracionState extends State<PantallaCrearValoracion> {
  final _formKey = GlobalKey<FormState>();
  final _comentarioController = TextEditingController();
  int _calificacion = 5;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.valoracionId != null) {
      _calificacion = widget.calificacionInicial ?? 5;
      _comentarioController.text = widget.comentarioInicial ?? '';
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _guardarValoracion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      Map<String, dynamic> result;

      if (widget.valoracionId != null) {
        // Actualizar valoración existente
        result = await ApiValoraciones.actualizar(
          valoracionId: widget.valoracionId!,
          calificacion: _calificacion,
          comentario: _comentarioController.text.trim(),
        );
      } else {
        // Crear nueva valoración
        result = await ApiValoraciones.crear(
          pacienteId: widget.pacienteId,
          medicoId: widget.medicoId,
          calificacion: _calificacion,
          comentario: _comentarioController.text.trim(),
        );
      }

      if (!mounted) return;

      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.valoracionId != null
                  ? 'Valoración actualizada exitosamente'
                  : 'Valoración creada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Retornar true para indicar éxito
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Error al guardar valoración'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.valoracionId != null
              ? 'Editar Valoración'
              : 'Valorar Médico',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del médico
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(widget.medicoNombre),
                  subtitle: const Text('Médico'),
                ),
              ),
              const SizedBox(height: 24),

              // Selector de calificación
              Text(
                'Calificación',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final estrella = index + 1;
                    return IconButton(
                      iconSize: 48,
                      onPressed: () {
                        setState(() {
                          _calificacion = estrella;
                        });
                      },
                      icon: Icon(
                        estrella <= _calificacion
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),
              ),
              Center(
                child: Text(
                  '$_calificacion de 5 estrellas',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 24),

              // Campo de comentario
              Text(
                'Comentario (opcional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _comentarioController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Cuéntanos sobre tu experiencia...',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_comentarioController.text.length}/500 caracteres',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _guardarValoracion,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.valoracionId != null
                              ? 'Actualizar Valoración'
                              : 'Enviar Valoración',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
