-- Crear la base de datos
CREATE DATABASE IF NOT EXISTS nlp_comentarios
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE nlp_comentarios;

-- Tabla de usuarios
CREATE TABLE usuarios (
    id VARCHAR(36) PRIMARY KEY,
    nombre_completo VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    tipo_documento VARCHAR(50) NOT NULL,
    numero_documento VARCHAR(50) UNIQUE NOT NULL,
    rol ENUM('admin', 'docente', 'estudiante') NOT NULL,
    departamento VARCHAR(100),
    password_hash VARCHAR(255) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla de programas académicos
CREATE TABLE programas (
    id VARCHAR(36) PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla de asignaturas
CREATE TABLE asignaturas (
    id VARCHAR(36) PRIMARY KEY,
    programa_id VARCHAR(36),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    creditos INT NOT NULL,
    semestre INT NOT NULL,
    descripcion TEXT,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (programa_id) REFERENCES programas(id)
) ENGINE=InnoDB;

-- Tabla de períodos académicos
CREATE TABLE periodos_academicos (
    id VARCHAR(36) PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla de matrículas (relación docente-asignatura-periodo)
CREATE TABLE matriculas (
    id VARCHAR(36) PRIMARY KEY,
    docente_id VARCHAR(36),
    asignatura_id VARCHAR(36),
    periodo_id VARCHAR(36),
    grupo VARCHAR(50) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (docente_id) REFERENCES usuarios(id),
    FOREIGN KEY (asignatura_id) REFERENCES asignaturas(id),
    FOREIGN KEY (periodo_id) REFERENCES periodos_academicos(id),
    UNIQUE KEY unique_matricula (docente_id, asignatura_id, periodo_id, grupo)
) ENGINE=InnoDB;

-- Tabla de evaluaciones
CREATE TABLE evaluaciones (
    id VARCHAR(36) PRIMARY KEY,
    matricula_id VARCHAR(36),
    fecha_inicio TIMESTAMP NOT NULL,
    fecha_fin TIMESTAMP NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (matricula_id) REFERENCES matriculas(id)
) ENGINE=InnoDB;

-- Tabla de criterios de evaluación
CREATE TABLE criterios_evaluacion (
    id VARCHAR(36) PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    peso DECIMAL(3,2) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (peso > 0 AND peso <= 1)
) ENGINE=InnoDB;

-- Tabla de respuestas de evaluación
CREATE TABLE respuestas_evaluacion (
    id VARCHAR(36) PRIMARY KEY,
    evaluacion_id VARCHAR(36),
    criterio_id VARCHAR(36),
    estudiante_id VARCHAR(36),
    calificacion INT CHECK (calificacion >= 1 AND calificacion <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (evaluacion_id) REFERENCES evaluaciones(id),
    FOREIGN KEY (criterio_id) REFERENCES criterios_evaluacion(id),
    FOREIGN KEY (estudiante_id) REFERENCES usuarios(id),
    UNIQUE KEY unique_respuesta (evaluacion_id, criterio_id, estudiante_id)
) ENGINE=InnoDB;

-- Tabla de comentarios
CREATE TABLE comentarios (
    id VARCHAR(36) PRIMARY KEY,
    evaluacion_id VARCHAR(36),
    estudiante_id VARCHAR(36),
    texto TEXT NOT NULL,
    anonimo BOOLEAN DEFAULT TRUE,
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (evaluacion_id) REFERENCES evaluaciones(id),
    FOREIGN KEY (estudiante_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- Tabla de análisis NLP
CREATE TABLE analisis_nlp (
    id VARCHAR(36) PRIMARY KEY,
    comentario_id VARCHAR(36),
    sentimiento DECIMAL(4,3) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    palabras_clave JSON NOT NULL,
    entidades JSON,
    embedding JSON,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (comentario_id) REFERENCES comentarios(id)
) ENGINE=InnoDB;

-- Tabla de reportes
CREATE TABLE reportes (
    id VARCHAR(36) PRIMARY KEY,
    evaluacion_id VARCHAR(36),
    tipo VARCHAR(50) NOT NULL,
    contenido JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (evaluacion_id) REFERENCES evaluaciones(id)
) ENGINE=InnoDB;

-- Índices para optimización
CREATE INDEX idx_usuarios_rol ON usuarios(rol);
CREATE INDEX idx_usuarios_estado ON usuarios(estado);
CREATE INDEX idx_asignaturas_programa ON asignaturas(programa_id);
CREATE INDEX idx_matriculas_docente ON matriculas(docente_id);
CREATE INDEX idx_matriculas_periodo ON matriculas(periodo_id);
CREATE INDEX idx_evaluaciones_matricula ON evaluaciones(matricula_id);
CREATE INDEX idx_comentarios_evaluacion ON comentarios(evaluacion_id);
CREATE INDEX idx_comentarios_estudiante ON comentarios(estudiante_id);
CREATE INDEX idx_analisis_comentario ON analisis_nlp(comentario_id);
CREATE INDEX idx_reportes_evaluacion ON reportes(evaluacion_id);

-- Procedimientos almacenados

-- Procedimiento para obtener estadísticas de un docente
DELIMITER $$
CREATE PROCEDURE GetTeacherStats(IN teacher_id VARCHAR(36))
BEGIN
    SELECT 
        COUNT(c.id) as total_comentarios,
        AVG(a.sentimiento) as promedio_sentimiento,
        COUNT(CASE WHEN a.sentimiento >= 0.5 THEN 1 END) as comentarios_positivos,
        COUNT(CASE WHEN a.sentimiento BETWEEN -0.5 AND 0.5 THEN 1 END) as comentarios_neutrales,
        COUNT(CASE WHEN a.sentimiento < -0.5 THEN 1 END) as comentarios_negativos
    FROM comentarios c
    JOIN analisis_nlp a ON c.id = a.comentario_id
    JOIN evaluaciones e ON c.evaluacion_id = e.id
    JOIN matriculas m ON e.matricula_id = m.id
    WHERE m.docente_id = teacher_id;
END$$
DELIMITER ;

-- Procedimiento para insertar un nuevo comentario con su análisis
DELIMITER $$
CREATE PROCEDURE InsertarComentarioConAnalisis(
    IN p_id VARCHAR(36),
    IN p_evaluacion_id VARCHAR(36),
    IN p_estudiante_id VARCHAR(36),
    IN p_texto TEXT,
    IN p_sentimiento DECIMAL(4,3),
    IN p_categoria VARCHAR(50),
    IN p_palabras_clave JSON,
    IN p_entidades JSON,
    IN p_embedding JSON
)
BEGIN
    START TRANSACTION;
    
    -- Insertar comentario
    INSERT INTO comentarios (id, evaluacion_id, estudiante_id, texto)
    VALUES (p_id, p_evaluacion_id, p_estudiante_id, p_texto);
    
    -- Insertar análisis NLP
    INSERT INTO analisis_nlp (
        id, 
        comentario_id, 
        sentimiento, 
        categoria, 
        palabras_clave, 
        entidades, 
        embedding
    )
    VALUES (
        UUID(), 
        p_id, 
        p_sentimiento, 
        p_categoria, 
        p_palabras_clave, 
        p_entidades, 
        p_embedding
    );
    
    COMMIT;
END$$
DELIMITER ;

-- Procedimiento para obtener comentarios similares
DELIMITER $$
CREATE PROCEDURE GetSimilarComments(
    IN comment_id VARCHAR(36),
    IN limit_count INT
)
BEGIN
    -- En MySQL, la similitud coseno se implementará en la aplicación
    -- Este procedimiento retorna los datos necesarios para el cálculo
    SELECT 
        c.id,
        c.texto,
        a.embedding
    FROM comentarios c
    JOIN analisis_nlp a ON c.id = a.comentario_id
    WHERE c.id != comment_id
    LIMIT limit_count;
END$$
DELIMITER ;

-- Triggers para mantener la integridad de los datos

-- Trigger para validar fechas de período académico
DELIMITER $$
CREATE TRIGGER check_periodo_dates
BEFORE INSERT ON periodos_academicos
FOR EACH ROW
BEGIN
    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha de fin debe ser posterior a la fecha de inicio';
    END IF;
END$$
DELIMITER ;

-- Trigger para validar fechas de evaluación
DELIMITER $$
CREATE TRIGGER check_evaluacion_dates
BEFORE INSERT ON evaluaciones
FOR EACH ROW
BEGIN
    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha de fin debe ser posterior a la fecha de inicio';
    END IF;
END$$
DELIMITER ;