<?php
// Прокси для запросов к 1С (обходит CORS)
// Если 1С не поддерживает CORS, укажите здесь адрес сервера 1С

$one_c_server = 'http://localhost:8080/hs/vitrina'; // ЗАМЕНИТЬ на адрес 1С

$path = $_SERVER['PATH_INFO'] ?? '/' . ltrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/api');
$method = $_SERVER['REQUEST_METHOD'];
$url = rtrim($one_c_server, '/') . '/' . ltrim($path, '/');

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CUSTOMREQUEST => $method,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Authorization: Basic ' . base64_encode('Логин:Пароль'), // ЗАМЕНИТЬ
    ],
    CURLOPT_POSTFIELDS => file_get_contents('php://input'),
    CURLOPT_TIMEOUT => 30,
]);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
http_response_code($http_code);
echo $response;
