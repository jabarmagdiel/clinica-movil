"""
Script para poblar el backend con datos de ejemplo de Historia Clínica y Consentimientos
Ejecutar con: python manage.py shell < seed_datos_historia_clinica.py
o desde Django shell: exec(open('seed_datos_historia_clinica.py').read())
"""

import random
from datetime import datetime, timedelta
from django.utils import timezone
from django.contrib.auth import get_user_model

User = get_user_model()

# Obtener modelos (ajustar según tu estructura)
from pacientes.models import Paciente
from medicos.models import Medico, MedicoEspecialidad
from consultas.models import Consulta
from examenes.models import Examen
from recetas.models import Receta
from consentimientos.models import Consentimiento

def crear_historia_clinica():
    """Crea datos de historia clínica para cada paciente"""
    
    pacientes = Paciente.objects.all()
    medico_especialidades = MedicoEspecialidad.objects.all()
    
    if not medico_especialidades.exists():
        print("⚠️  No hay médico-especialidades disponibles. Crea primero médicos y especialidades.")
        return
    
    # Datos de ejemplo para diagnósticos
    diagnosticos = [
        "Hipertensión arterial controlada",
        "Diabetes tipo 2",
        "Resfriado común",
        "Gripe",
        "Dolor de cabeza tensional",
        "Ansiedad leve",
        "Artritis reumatoide",
        "Asma bronquial",
        "Gastritis crónica",
        "Dermatitis atópica",
    ]
    
    motivos = [
        "Control rutinario",
        "Dolor de cabeza",
        "Fiebre y malestar general",
        "Dolor abdominal",
        "Revisión de resultados",
        "Seguimiento de tratamiento",
        "Consulta preventiva",
        "Síntomas respiratorios",
    ]
    
    # Tipos de exámenes
    tipos_examenes = [
        "Hemograma completo",
        "Glucosa en ayunas",
        "Perfil lipídico",
        "Radiografía de tórax",
        "Electrocardiograma",
        "Ecografía abdominal",
        "Análisis de orina",
        "Prueba de función hepática",
        "TSH y T4",
        "Vitamina D",
    ]
    
    resultados_examenes = [
        "Valores normales",
        "Ligeramente elevado, requiere seguimiento",
        "Dentro de parámetros normales",
        "Resultados satisfactorios",
        "Se requiere nueva evaluación",
    ]
    
    # Medicamentos comunes
    medicamentos_list = [
        "Paracetamol 500mg",
        "Ibuprofeno 400mg",
        "Amoxicilina 500mg",
        "Omeprazol 20mg",
        "Loratadina 10mg",
        "Metformina 500mg",
        "Losartán 50mg",
        "Atorvastatina 20mg",
        "Amlodipino 5mg",
        "Salbutamol inhalador",
    ]
    
    indicaciones_list = [
        "Tomar cada 8 horas con alimentos",
        "Tomar una vez al día en ayunas",
        "Aplicar 2 veces al día",
        "Tomar con abundante agua",
        "No tomar con alcohol",
        "Seguir tratamiento por 7 días",
        "Tomar antes de dormir",
    ]
    
    # Tipos de procedimientos para consentimientos
    tipos_procedimientos = [
        "Cirugía menor",
        "Endoscopia digestiva",
        "Biopsia",
        "Intervención quirúrgica",
        "Procedimiento diagnóstico",
        "Tratamiento invasivo",
        "Anestesia general",
    ]
    
    # Contenidos de consentimientos
    contenidos_consentimientos = [
        "Consentimiento informado para procedimiento médico. El paciente ha sido informado sobre los riesgos y beneficios del procedimiento.",
        "Autorización para realizar intervención quirúrgica bajo anestesia. Se han explicado los posibles efectos secundarios.",
        "Consentimiento para procedimiento diagnóstico invasivo. El paciente comprende los riesgos asociados.",
        "Autorización para tratamiento médico. Se ha proporcionado información completa sobre alternativas.",
    ]
    
    total_creados = {
        'consultas': 0,
        'examenes': 0,
        'recetas': 0,
        'consentimientos': 0,
    }
    
    for paciente in pacientes:
        print(f"\n📋 Creando historia clínica para {paciente.nombre} {paciente.apellido}...")
        
        # Obtener médicos asignados aleatoriamente
        med_esp_list = list(medico_especialidades)
        if not med_esp_list:
            continue
        
        # Crear 3-6 consultas por paciente
        num_consultas = random.randint(3, 6)
        for i in range(num_consultas):
            fecha = timezone.now() - timedelta(days=random.randint(1, 180))
            med_esp = random.choice(med_esp_list)
            
            consulta = Consulta.objects.create(
                paciente=paciente,
                medico_especialidad=med_esp,
                fecha=fecha,
                motivo=random.choice(motivos),
                diagnostico=random.choice(diagnosticos),
                observaciones=f"Consulta de seguimiento. Paciente estable.",
                created_at=fecha,
                updated_at=fecha,
            )
            total_creados['consultas'] += 1
        
        # Crear 2-4 exámenes por paciente
        num_examenes = random.randint(2, 4)
        for i in range(num_examenes):
            fecha = timezone.now() - timedelta(days=random.randint(1, 120))
            med_esp = random.choice(med_esp_list)
            
            examen = Examen.objects.create(
                paciente=paciente,
                medico_especialidad=med_esp,
                tipo_examen=random.choice(tipos_examenes),
                fecha=fecha,
                resultado=random.choice(resultados_examenes),
                observaciones="Examen realizado según protocolo estándar.",
                created_at=fecha,
                updated_at=fecha,
            )
            total_creados['examenes'] += 1
        
        # Crear 2-5 recetas por paciente
        num_recetas = random.randint(2, 5)
        for i in range(num_recetas):
            fecha = timezone.now() - timedelta(days=random.randint(1, 90))
            med_esp = random.choice(med_esp_list)
            
            # Seleccionar 1-3 medicamentos aleatorios
            medicamentos = ", ".join(random.sample(medicamentos_list, random.randint(1, 3)))
            
            receta = Receta.objects.create(
                paciente=paciente,
                medico_especialidad=med_esp,
                fecha=fecha,
                medicamentos=medicamentos,
                indicaciones=random.choice(indicaciones_list),
                created_at=fecha,
                updated_at=fecha,
            )
            total_creados['recetas'] += 1
        
        # Crear 2-4 consentimientos por paciente (algunos pendientes, algunos firmados)
        num_consentimientos = random.randint(2, 4)
        for i in range(num_consentimientos):
            fecha_creacion = timezone.now() - timedelta(days=random.randint(1, 60))
            med_esp = random.choice(med_esp_list)
            
            # 60% pendientes, 40% firmados
            estado = 'pendiente' if random.random() < 0.6 else 'firmado'
            fecha_firma = None
            if estado == 'firmado':
                fecha_firma = fecha_creacion + timedelta(days=random.randint(1, 5))
            
            consentimiento = Consentimiento.objects.create(
                paciente=paciente,
                medico_especialidad=med_esp,
                tipo=random.choice(tipos_procedimientos),
                procedimiento=random.choice(tipos_procedimientos),
                contenido=random.choice(contenidos_consentimientos),
                estado=estado,
                fecha_creacion=fecha_creacion,
                fecha_firma=fecha_firma,
                tipo_firma='biometrica' if estado == 'firmado' and random.random() < 0.5 else 'pin' if estado == 'firmado' else None,
                created_at=fecha_creacion,
                updated_at=fecha_firma or fecha_creacion,
            )
            total_creados['consentimientos'] += 1
    
    print("\n✅ Resumen de datos creados:")
    print(f"  📝 Consultas: {total_creados['consultas']}")
    print(f"  🔬 Exámenes: {total_creados['examenes']}")
    print(f"  💊 Recetas: {total_creados['recetas']}")
    print(f"  📋 Consentimientos: {total_creados['consentimientos']}")
    print("\n✨ ¡Datos de historia clínica creados exitosamente!")

if __name__ == '__main__':
    crear_historia_clinica()

