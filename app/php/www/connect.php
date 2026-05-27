<?php
/**
 * Connexion à la base de données.
 *
 * Les paramètres sont lus depuis des variables d'environnement
 * (injectées par Docker / Kubernetes). Des valeurs par défaut sont
 * fournies pour faciliter le développement local.
 */

$host     = getenv('DB_HOST')     ?: 'db';
$port     = getenv('DB_PORT')     ?: '3306';
$dbname   = getenv('DB_NAME')     ?: 'gestion_produits';
$username = getenv('DB_USER')     ?: 'root';
$password = getenv('DB_PASSWORD') ?: 'root';
$driver   = getenv('DB_DRIVER')   ?: 'mysql';

// Construction du DSN selon le pilote. La branche `dev` du dépôt fournit
// une variante PostgreSQL en surchargeant DB_DRIVER=pgsql.
$dsn = "{$driver}:host={$host};port={$port};dbname={$dbname}";

try {
    $db = new PDO($dsn, $username, $password);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    http_response_code(500);
    error_log('[gestion-produits] DB connection failed: ' . $e->getMessage());
    exit('Erreur de connexion à la base de données.');
}
