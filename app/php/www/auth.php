<?php
    if (isset($_POST['us_login']) and isset($_POST['us_password'])) {
        session_start();
        include 'connect.php';

        ini_set('display_errors', '1');

        // Branche dev : on calcule le hash SHA-256 cote PHP plutot que cote
        // SQL (SHA2() est specifique MySQL et n'existe pas en PostgreSQL).
        // Ce changement est neutre pour MySQL (meme hash produit).
        $hashed = hash('sha256', $_POST['us_password']);

        $sql = "SELECT * FROM utilisateurs WHERE us_login = ? AND us_password = ?";
        $stmt = $db->prepare($sql);
        $stmt->bindParam(1, $_POST['us_login']);
        $stmt->bindParam(2, $hashed);
        $stmt->execute();
        $res = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if ($res != false) {

            if ( count($res) > 0) {
                // Utilisateur trouvé dans la base
                $utilisateur = $res[0];
                $_SESSION['login'] = $utilisateur['us_login'];
                header("Location: home.php");
            } else {
                header("Location: index.php");
            }
        } else {
            header("Location: BADUSER.html");
        }
    }
?>
