-- tabla: socio
create table socio (
    id_socio          int           not null identity(1,1),
    dui               char(10)      not null,   -- formato salvadoreno: 00000000-0
    nombre            varchar(50)   not null,
    apellido          varchar(50)   not null,
    fecha_nacimiento  date          not null,
    telefono          varchar(9)    not null,
    correo            varchar(100)  not null,
    fecha_registro    date          not null constraint df_socio_fecha_registro default getdate(),
    estado            varchar(15)   not null constraint df_socio_estado default 'ACTIVO',
 
    constraint pk_socio primary key (id_socio),
 
    constraint uq_socio_dui unique (dui),
    constraint uq_socio_correo unique (correo),
    constraint ck_socio_dui
        check (dui like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]'),
    constraint ck_socio_nombre check (len(trim(nombre)) > 0),
    constraint ck_socio_apellido check (len(trim(apellido)) > 0),
    constraint ck_socio_fecha_nacimiento check (fecha_nacimiento <= getdate()),
    constraint ck_socio_telefono
        check (telefono like '[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'),
    constraint ck_socio_correo check (correo like '%@%.%'),
    constraint ck_socio_fechas check (fecha_registro >= fecha_nacimiento),
    constraint ck_socio_estado check (estado in ('ACTIVO', 'INACTIVO'))
);
go
 
-- tabla: plan_membresia
create table plan_membresia (
    id_plan            int            not null identity(1,1),
    nombre             varchar(50)    not null,
    precio             decimal(10,2)  not null,
    duracion_dias      smallint       not null,
    max_clases_semana  tinyint        null,     -- null = clases ilimitadas
 
    constraint pk_plan_membresia primary key (id_plan),
 
    constraint uq_plan_membresia_nombre unique (nombre),
    constraint ck_plan_membresia_precio check (precio > 0),
    constraint ck_plan_membresia_duracion_dias check (duracion_dias > 0),
    constraint ck_plan_membresia_max_clases_semana check (max_clases_semana > 0)
);
go
 
-- tabla: especialidad
create table especialidad (
    id_especialidad  int           not null identity(1,1),
    nombre           varchar(50)   not null,
    descripcion      varchar(200)  null,
 
    constraint pk_especialidad primary key (id_especialidad),
 
    constraint uq_especialidad_nombre unique (nombre)
);
go
 
-- tabla: sala
create table sala (
    id_sala    int          not null identity(1,1),
    nombre     varchar(50)  not null,
    capacidad  smallint     not null,
 
    constraint pk_sala primary key (id_sala),
 
    constraint uq_sala_nombre unique (nombre),
    constraint ck_sala_capacidad check (capacidad > 0)
);
go
 
-- tabla: entrenador
create table entrenador (
    id_entrenador       int           not null identity(1,1),
    dui                 char(10)      not null,   -- formato salvadoreno: 00000000-0
    nombre              varchar(50)   not null,
    apellido            varchar(50)   not null,
    telefono            varchar(9)    not null,
    correo              varchar(100)  not null,
    fecha_contratacion  date          not null,
    estado              varchar(15)   not null constraint df_entrenador_estado default 'ACTIVO',
 
    constraint pk_entrenador primary key (id_entrenador),
 
    constraint uq_entrenador_dui unique (dui),
    constraint uq_entrenador_correo unique (correo),
    constraint ck_entrenador_dui
        check (dui like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]'),
    constraint ck_entrenador_nombre check (len(trim(nombre)) > 0),
    constraint ck_entrenador_apellido check (len(trim(apellido)) > 0),
    constraint ck_entrenador_telefono
        check (telefono like '[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'),
    constraint ck_entrenador_correo check (correo like '%@%.%'),
    constraint ck_entrenador_fecha_contratacion
        check (fecha_contratacion <= getdate()),
    constraint ck_entrenador_estado check (estado in ('ACTIVO', 'INACTIVO'))
);
go
  
-- tabla: contacto_emergencia
-- entidad debil de socio: pk compuesta = id_socio + num_contacto (parcial)
create table contacto_emergencia (
    id_socio      int           not null,
    num_contacto  tinyint       not null,
    nombre        varchar(100)  not null,
    telefono      varchar(9)    not null,
    parentesco    varchar(20)   not null,
 
    constraint pk_contacto_emergencia primary key (id_socio, num_contacto),
 
    constraint fk_contacto_emergencia_socio
        foreign key (id_socio) references socio(id_socio)
        on delete cascade        -- sin socio, el contacto no tiene sentido
        on update cascade,
 
    constraint ck_contacto_emergencia_num_contacto check (num_contacto > 0),
    constraint ck_contacto_emergencia_nombre check (len(trim(nombre)) > 0),
    constraint ck_contacto_emergencia_telefono
        check (telefono like '[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'),
    constraint ck_contacto_emergencia_parentesco
        check (parentesco in ('madre', 'padre', 'hermano', 'hermana', 'conyuge',
                              'hijo', 'hija', 'abuelo', 'abuela', 'tio', 'tia',
                              'amigo', 'otro'))
);
go
 
-- tabla: membresia (compra concreta de un plan por un socio)
create table membresia (
    id_membresia  int          not null identity(1,1),
    id_socio      int          not null,
    id_plan       int          not null,
    fecha_inicio  date         not null,
    fecha_fin     date         not null,
    estado        varchar(15)  not null constraint df_membresia_estado default 'ACTIVA',
 
    constraint pk_membresia primary key (id_membresia),
 
    constraint fk_membresia_socio
        foreign key (id_socio) references socio(id_socio)
        on delete no action      -- restrict: no se borra un socio con historial
        on update cascade,
    constraint fk_membresia_plan_membresia
        foreign key (id_plan) references plan_membresia(id_plan)
        on delete no action      -- restrict: no se borra un plan ya vendido
        on update cascade,
 
    constraint ck_membresia_fechas check (fecha_fin > fecha_inicio),
    constraint ck_membresia_estado
        check (estado in ('ACTIVA', 'VENCIDA', 'CANCELADA', 'SUSPENDIDA'))
);
go
 
-- tabla: tipo_clase (catalogo: yoga, spinning, zumba...)
create table tipo_clase (
    id_tipo_clase    int           not null identity(1,1),
    id_especialidad  int           not null,
    nombre           varchar(50)   not null,
    descripcion      varchar(200)  null,
    nivel            varchar(15)   not null constraint df_tipo_clase_nivel default 'BASICO',
 
    constraint pk_tipo_clase primary key (id_tipo_clase),
 
    constraint fk_tipo_clase_especialidad
        foreign key (id_especialidad) references especialidad(id_especialidad)
        on delete no action      -- restrict
        on update cascade,
 
    constraint uq_tipo_clase_nombre unique (nombre),
    constraint ck_tipo_clase_nivel
        check (nivel in ('BASICO', 'INTERMEDIO', 'AVANZADO'))
);
go
 
-- tabla: entrenador_especialidad 
-- entidad debil: pk compuesta = pk de ambas entidades propietarias
create table entrenador_especialidad (
    id_entrenador        int   not null,
    id_especialidad      int   not null,
    fecha_certificacion  date  not null,
 
    constraint pk_entrenador_especialidad
        primary key (id_entrenador, id_especialidad),
 
    constraint fk_entrenador_especialidad_entrenador
        foreign key (id_entrenador) references entrenador(id_entrenador)
        on delete cascade        -- la asignacion depende del entrenador
        on update cascade,
    constraint fk_entrenador_especialidad_especialidad
        foreign key (id_especialidad) references especialidad(id_especialidad)
        on delete no action      -- restrict: no se borra una especialidad en uso
        on update cascade,
 
    constraint ck_entrenador_especialidad_fecha_certificacion
        check (fecha_certificacion <= getdate())
);
go
 

-- tabla: clase 
create table clase (
    id_clase       int          not null identity(1,1),
    id_tipo_clase  int          not null,
    id_entrenador  int          not null,
    id_sala        int          not null,
    fecha          date         not null,
    hora_inicio    time(0)      not null,
    hora_fin       time(0)      not null,
    cupo_max       smallint     not null,
    estado         varchar(15)  not null constraint df_clase_estado default 'PROGRAMADA',
 
    constraint pk_clase primary key (id_clase),
 
    constraint fk_clase_tipo_clase
        foreign key (id_tipo_clase) references tipo_clase(id_tipo_clase)
        on delete no action      -- restrict
        on update cascade,
    constraint fk_clase_entrenador
        foreign key (id_entrenador) references entrenador(id_entrenador)
        on delete no action      -- restrict: el entrenador se da de baja (estado)
        on update cascade,
    constraint fk_clase_sala
        foreign key (id_sala) references sala(id_sala)
        on delete no action      -- restrict
        on update cascade,
 
    constraint ck_clase_horas check (hora_fin > hora_inicio),
    constraint ck_clase_cupo_max check (cupo_max > 0),
    constraint ck_clase_estado
        check (estado in ('PROGRAMADA', 'REALIZADA', 'CANCELADA'))
);
go
 
-- tabla: pago (monto = valor realmente cobrado, no se recalcula desde plan)
create table pago (
    id_pago             int            not null identity(1,1),
    id_membresia        int            not null,
    fecha_pago          date           not null constraint df_pago_fecha_pago default getdate(),
    monto               decimal(10,2)  not null,
    metodo_pago         varchar(15)    not null,
    estado              varchar(15)    not null constraint df_pago_estado default 'PENDIENTE',
    numero_comprobante  varchar(20)    not null,
 
    constraint pk_pago primary key (id_pago),
 
    constraint fk_pago_membresia
        foreign key (id_membresia) references membresia(id_membresia)
        on delete no action      -- restrict: los pagos nunca se pierden
        on update cascade,
 
    constraint uq_pago_numero_comprobante unique (numero_comprobante),
    constraint ck_pago_fecha_pago check (fecha_pago <= getdate()),
    constraint ck_pago_monto check (monto > 0),
    constraint ck_pago_metodo_pago
        check (metodo_pago in ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    constraint ck_pago_estado
        check (estado in ('PAGADO', 'PENDIENTE', 'ANULADO'))
);
go
 
-- entidad debil: pk compuesta = (id_socio, id_clase)
create table reserva (
    id_socio       int          not null,
    id_clase       int          not null,
    fecha_reserva  date         not null constraint df_reserva_fecha_reserva default getdate(),
    estado         varchar(15)  not null constraint df_reserva_estado default 'RESERVADA',
 
    constraint pk_reserva primary key (id_socio, id_clase),
 
    constraint fk_reserva_socio
        foreign key (id_socio) references socio(id_socio)
        on delete no action      -- restrict: la asistencia es historial
        on update cascade,
    constraint fk_reserva_clase
        foreign key (id_clase) references clase(id_clase)
        on delete no action      -- restrict: las clases se cancelan, no se borran
        on update cascade,
 
    constraint ck_reserva_estado
        check (estado in ('RESERVADA', 'ASISTIO', 'NO_ASISTIO', 'CANCELADA'))
);
go

