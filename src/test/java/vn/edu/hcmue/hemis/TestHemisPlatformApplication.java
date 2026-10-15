package vn.edu.hcmue.hemis;

import org.springframework.boot.SpringApplication;

public class TestHemisPlatformApplication {

	public static void main(String[] args) {
		SpringApplication.from(HemisPlatformApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
