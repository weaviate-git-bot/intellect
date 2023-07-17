/* ---------------------------------------------------- */
/*  Generated by Enterprise Architect Version 16.1 		*/
/*  Created On : 11-Jul-2023 2:10:03 AM 				*/
/*  DBMS       : PostgreSQL 						*/
/* ---------------------------------------------------- */

/* Drop Sequences for Autonumber Columns */



/* Drop Tables */

DROP TABLE IF EXISTS account CASCADE
;

DROP TABLE IF EXISTS account CASCADE
;

DROP TABLE IF EXISTS account_agent CASCADE
;

DROP TABLE IF EXISTS account_agent_function CASCADE
;

DROP TABLE IF EXISTS account_agent_service CASCADE
;

DROP TABLE IF EXISTS account_member CASCADE
;

DROP TABLE IF EXISTS account_member_role CASCADE
;

DROP TABLE IF EXISTS agent_message CASCADE
;

DROP TABLE IF EXISTS agent_message_digest CASCADE
;

DROP TABLE IF EXISTS channel CASCADE
;

DROP TABLE IF EXISTS feature CASCADE
;

DROP TABLE IF EXISTS features CASCADE
;

DROP TABLE IF EXISTS function CASCADE
;

DROP TABLE IF EXISTS intuition_pump CASCADE
;

DROP TABLE IF EXISTS message CASCADE
;

DROP TABLE IF EXISTS message_features CASCADE
;

DROP TABLE IF EXISTS message_functions CASCADE
;

DROP TABLE IF EXISTS message_nesting CASCADE
;

DROP TABLE IF EXISTS message_services CASCADE
;

DROP TABLE IF EXISTS message_subject CASCADE
;

DROP TABLE IF EXISTS message_subject_tag CASCADE
;

DROP TABLE IF EXISTS prompt_lingua CASCADE
;

DROP TABLE IF EXISTS service CASCADE
;

DROP TABLE IF EXISTS subject_vector CASCADE
;

DROP TABLE IF EXISTS tag_vector CASCADE
;

DROP TABLE IF EXISTS "user" CASCADE
;

DROP TABLE IF EXISTS user_credential CASCADE
;

DROP TABLE IF EXISTS user_credential_oauth CASCADE
;

DROP TABLE IF EXISTS user_credential_login_pass CASCADE
;

DROP TABLE IF EXISTS versioned_string CASCADE
;

DROP TABLE IF EXISTS versioned_string_history CASCADE
;

/* Create Tables */

CREATE TABLE account
(
	identifier bigint NOT NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE account_agent
(
	identifier bigint NOT NULL,
	account bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE account_agent_function
(
	identifier bigint NOT NULL,
	account_agent bigint NULL,
	function bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE account_agent_service
(
	identifier bigint NOT NULL,
	account_agent bigint NULL,
	service bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE account_member
(
	identifier bigint NOT NULL,
	account bigint NULL,
	"user" bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE account_member_role
(
	identifier bigint NOT NULL,
	account_member bigint NULL,
	account_role bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE agent_message
(
	identifier bigint NOT NULL,
	account_agent bigint NULL,
	content text NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE agent_message_digest
(
	identifier bigint NOT NULL,
	agent_message bigint NULL,
	message bigint NULL
)
;

CREATE TABLE channel
(
	identifier bigint NOT NULL,
	account bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE feature
(
	identifier bigint NOT NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE features
(
	identifier bigint NULL,
	message bigint NULL,
	feature varchar(50) NULL
)
;

CREATE TABLE function
(
	identifier bigint NOT NULL,
	prompt_file varchar(50) NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE intuition_pump
(
	identifier bigint NOT NULL,
	prompt_file varchar(50) NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE message
(
	identifier bigint NOT NULL,
	sender bigint NULL,
	channel bigint NULL,
	depth smallint NULL,
	contents text NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE message_features
(
	identifier bigint NOT NULL,
	message bigint NULL,
	feature bigint NULL
)
;

CREATE TABLE message_functions
(
	identifier bigint NOT NULL,
	message bigint NULL,
	function bigint NULL
)
;

CREATE TABLE message_nesting
(
	message bigint NULL,
	depth bigint NULL,
	ancestor bigint NULL
)
;

CREATE TABLE message_services
(
	identifier bigint NOT NULL,
	message bigint NULL,
	service bigint NULL
)
;

CREATE TABLE message_subject
(
	identifier bigint NOT NULL,
	message bigint NULL,
	subject_vector bigint NULL,
	account_agent bigint NULL
)
;

CREATE TABLE message_subject_tag
(
	messsage_subject bigint NOT NULL,
	tag_vector bigint NOT NULL
)
;

CREATE TABLE prompt_lingua
(
	identifier bigint NOT NULL,
	prompt_file varchar(50) NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE service
(
	identifier bigint NOT NULL,
	prompt_file varchar(50) NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE subject_vector
(
	identifier bigint NOT NULL
)
;

CREATE TABLE tag_vector
(
	identifier bigint NOT NULL
)
;

CREATE TABLE "user"
(
	identifier bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE user_credential
(
	identifier bigint NOT NULL,
	"user" bigint NULL,
    details bigint NOT NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE user_credential_oauth
(
	identifier bigint NOT NULL,
	provider varchar(50) NULL,
	account varchar(50) NULL
)
;

CREATE TABLE user_credential_login_pass
(
	identifier bigint NOT NULL,
	account varchar(50) NULL,
	password varchar(50) NULL
)
;

CREATE TABLE versioned_string
(
	identifier bigint NOT NULL,
	version bigint NULL,
	title varchar(50) NULL,
	body varchar(50) NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

CREATE TABLE versioned_string_history
(
	identifier bigint NOT NULL,
	versioned_string bigint NULL,
	version bigint NULL,
	title varchar(50) NULL,
	body varchar(50) NULL,
    created_on timestamp NOT NULL,
    modified_on timestamp NOT NULL,
    deleted_on timestamp
)
;

/* Create Primary Keys, Indexes, Uniques, Checks */

ALTER TABLE account ADD CONSTRAINT "PK_account"
	PRIMARY KEY (identifier)
;


ALTER TABLE account_agent ADD CONSTRAINT "PK_account_agent"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_account_agent_account" ON account_agent (account ASC)
;

ALTER TABLE account_agent_function ADD CONSTRAINT "PK_account_agent_function"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_account_agent_function_account_agent" ON account_agent_function (account_agent ASC)
;

CREATE INDEX "IXFK_account_agent_function_function" ON account_agent_function (function ASC)
;

ALTER TABLE account_agent_service ADD CONSTRAINT "PK_account_agent_service"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_account_agent_service_account_agent" ON account_agent_service (account_agent ASC)
;

CREATE INDEX "IXFK_account_agent_service_service" ON account_agent_service (service ASC)
;

ALTER TABLE account_member ADD CONSTRAINT "PK_account_member"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_account_member_account" ON account_member (account ASC)
;

CREATE INDEX "IXFK_account_member_user" ON account_member ("user" ASC)
;

ALTER TABLE account_member_role ADD CONSTRAINT "PK_account_member_role"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_account_member_role_account_member" ON account_member_role (account_member ASC)
;

ALTER TABLE agent_message ADD CONSTRAINT "PK_agent_message"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_agent_message_account_agent" ON agent_message (account_agent ASC)
;

ALTER TABLE agent_message_digest ADD CONSTRAINT "PK_agent_message_digest"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_agent_message_digest_agent_message" ON agent_message_digest (agent_message ASC)
;

CREATE INDEX "IXFK_agent_message_digest_message" ON agent_message_digest (message ASC)
;

ALTER TABLE channel ADD CONSTRAINT "PK_channel"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_channel_account" ON channel (account ASC)
;

ALTER TABLE feature ADD CONSTRAINT "PK_feature"
	PRIMARY KEY (identifier)
;

ALTER TABLE function ADD CONSTRAINT "PK_function"
	PRIMARY KEY (identifier)
;

ALTER TABLE intuition_pump ADD CONSTRAINT "PK_intuition_pump"
	PRIMARY KEY (identifier)
;

ALTER TABLE message ADD CONSTRAINT "PK_message"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_message_channel" ON message (channel ASC)
;

ALTER TABLE message_features ADD CONSTRAINT "PK_message_features"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_message_features_feature" ON message_features (feature ASC)
;

CREATE INDEX "IXFK_message_features_message" ON message_features (message ASC)
;

ALTER TABLE message_functions ADD CONSTRAINT "PK_message_functions"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_message_functions_function" ON message_functions (function ASC)
;

CREATE INDEX "IXFK_message_functions_message" ON message_functions (message ASC)
;

CREATE INDEX "IXFK_message_nesting_message" ON message_nesting (ancestor ASC)
;

CREATE INDEX "IXFK_message_nesting_message_02" ON message_nesting (message ASC)
;

ALTER TABLE message_services ADD CONSTRAINT "PK_message_services"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_message_services_message" ON message_services (message ASC)
;

CREATE INDEX "IXFK_message_services_service" ON message_services (service ASC)
;

ALTER TABLE message_subject ADD CONSTRAINT "PK_message_subject"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_message_subject_account_agent" ON message_subject (account_agent ASC)
;

CREATE INDEX "IXFK_message_subject_message" ON message_subject (message ASC)
;

CREATE INDEX "IXFK_message_subject_subject_vector" ON message_subject (subject_vector ASC)
;

ALTER TABLE message_subject_tag ADD CONSTRAINT "PK_message_subject_tag"
	PRIMARY KEY (messsage_subject,tag_vector)
;

CREATE INDEX "IXFK_message_subject_tag_message_subject" ON message_subject_tag (messsage_subject ASC)
;

CREATE INDEX "IXFK_message_subject_tag_tag_vector" ON message_subject_tag (tag_vector ASC)
;

ALTER TABLE prompt_lingua ADD CONSTRAINT "PK_prompt_lingua"
	PRIMARY KEY (identifier)
;

ALTER TABLE service ADD CONSTRAINT "PK_service"
	PRIMARY KEY (identifier)
;

ALTER TABLE subject_vector ADD CONSTRAINT "PK_subject_vector"
	PRIMARY KEY (identifier)
;

ALTER TABLE tag_vector ADD CONSTRAINT "PK_tag_vector"
	PRIMARY KEY (identifier)
;

ALTER TABLE "user" ADD CONSTRAINT "PK_user"
	PRIMARY KEY (identifier)
;

ALTER TABLE user_credential ADD CONSTRAINT "PK_user_credential"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_user_credential_user" ON user_credential ("user" ASC)
;

ALTER TABLE user_credential_oauth ADD CONSTRAINT "PK_user_credential_oauth"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_user_credential_oauth_user_credential" ON user_credential_oauth (identifier ASC)
;

ALTER TABLE user_credential_login_pass ADD CONSTRAINT "PK_user_credential_login_pass"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_user_credential_login_pass_user_credential" ON user_credential_login_pass (identifier ASC)
;

ALTER TABLE versioned_string ADD CONSTRAINT "PK_versioned_string"
	PRIMARY KEY (identifier)
;

ALTER TABLE versioned_string_history ADD CONSTRAINT "PK_versioned_string_history"
	PRIMARY KEY (identifier)
;

CREATE INDEX "IXFK_versioned_string_history_versioned_string" ON versioned_string_history (versioned_string ASC)
;

/* Create Foreign Key Constraints */

ALTER TABLE account_agent ADD CONSTRAINT "FK_account_agent_account"
	FOREIGN KEY (account) REFERENCES account (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_agent_function ADD CONSTRAINT "FK_account_agent_function_account_agent"
	FOREIGN KEY (account_agent) REFERENCES account_agent (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_agent_function ADD CONSTRAINT "FK_account_agent_function_function"
	FOREIGN KEY (function) REFERENCES function (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_agent_service ADD CONSTRAINT "FK_account_agent_service_account_agent"
	FOREIGN KEY (account_agent) REFERENCES account_agent (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_agent_service ADD CONSTRAINT "FK_account_agent_service_service"
	FOREIGN KEY (service) REFERENCES service (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_member ADD CONSTRAINT "FK_account_member_account"
	FOREIGN KEY (account) REFERENCES account (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_member ADD CONSTRAINT "FK_account_member_user"
	FOREIGN KEY ("user") REFERENCES "user" (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE account_member_role ADD CONSTRAINT "FK_account_member_role_account_member"
	FOREIGN KEY (account_member) REFERENCES account_member (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE agent_message ADD CONSTRAINT "FK_agent_message_account_agent"
	FOREIGN KEY (account_agent) REFERENCES account_agent (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE agent_message_digest ADD CONSTRAINT "FK_agent_message_digest_agent_message"
	FOREIGN KEY (agent_message) REFERENCES agent_message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE agent_message_digest ADD CONSTRAINT "FK_agent_message_digest_message"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE channel ADD CONSTRAINT "FK_channel_account"
	FOREIGN KEY (account) REFERENCES account (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message ADD CONSTRAINT "FK_message_channel"
	FOREIGN KEY (channel) REFERENCES channel (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_features ADD CONSTRAINT "FK_message_features_feature"
	FOREIGN KEY (feature) REFERENCES feature (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_features ADD CONSTRAINT "FK_message_features_message"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_functions ADD CONSTRAINT "FK_message_functions_function"
	FOREIGN KEY (function) REFERENCES function (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_functions ADD CONSTRAINT "FK_message_functions_message"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_nesting ADD CONSTRAINT "FK_message_nesting_message"
	FOREIGN KEY (ancestor) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_nesting ADD CONSTRAINT "FK_message_nesting_message_02"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_services ADD CONSTRAINT "FK_message_services_message"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_services ADD CONSTRAINT "FK_message_services_service"
	FOREIGN KEY (service) REFERENCES service (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_subject ADD CONSTRAINT "FK_message_subject_account_agent"
	FOREIGN KEY (account_agent) REFERENCES account_agent (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_subject ADD CONSTRAINT "FK_message_subject_message"
	FOREIGN KEY (message) REFERENCES message (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_subject ADD CONSTRAINT "FK_message_subject_subject_vector"
	FOREIGN KEY (subject_vector) REFERENCES subject_vector (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_subject_tag ADD CONSTRAINT "FK_message_subject_tag_message_subject"
	FOREIGN KEY (messsage_subject) REFERENCES message_subject (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE message_subject_tag ADD CONSTRAINT "FK_message_subject_tag_tag_vector"
	FOREIGN KEY (tag_vector) REFERENCES tag_vector (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE user_credential ADD CONSTRAINT "FK_user_credential_user"
	FOREIGN KEY ("user") REFERENCES "user" (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE user_credential_oauth ADD CONSTRAINT "FK_user_credential_oauth_user_credential"
	FOREIGN KEY (identifier) REFERENCES user_credential (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE user_credential_login_pass ADD CONSTRAINT "FK_user_credential_login_pass_user_credential"
	FOREIGN KEY (identifier) REFERENCES user_credential (identifier) ON DELETE No Action ON UPDATE No Action
;

ALTER TABLE versioned_string_history ADD CONSTRAINT "FK_versioned_string_history_versioned_string"
	FOREIGN KEY (versioned_string) REFERENCES versioned_string (identifier) ON DELETE No Action ON UPDATE No Action
;

/* Create Table Comments, Sequences for Autonumber Columns */
