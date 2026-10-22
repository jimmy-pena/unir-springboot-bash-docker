package com.unir.ejemplo.hola_docker;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HolaController {

    @GetMapping("/hello")
    public String saludar() {
        return "Hello!";
    }
}