`timescale 1ns/1ps

module tb_pwm_gen;

    // Semnale de ceas si reset
    reg clk;
    reg rst_n;

    // Registri periferic
    reg pwm_en;
    reg [15:0] period;
    reg [7:0] functions;
    reg [15:0] compare1;
    reg [15:0] compare2;
    reg [15:0] count_val;

    // Output PWM
    wire pwm_out;

    // Instantiere modul PWM
    pwm_gen uut (
        .clk(clk),
        .rst_n(rst_n),
        .pwm_en(pwm_en),
        .period(period),
        .functions(functions),
        .compare1(compare1),
        .compare2(compare2),
        .count_val(count_val),
        .pwm_out(pwm_out)
    );

    // Generare ceas
    initial clk = 0;
    always #5 clk = ~clk; // Perioada 10ns => frecventa 100MHz

    // Dump pentru GTKWave
    initial begin
        $dumpfile("tb_pwm_gen.vcd");
        $dumpvars(0, tb_pwm_gen);
    end

    // Functie pentru simularea unui overflow al contorului
    task do_overflow(input [15:0] max_count);
        integer i;
        begin
            for (i = 0; i <= max_count; i = i + 1) begin
                count_val = i;
                #10;
            end
        end
    endtask

    // Variabile pentru test 6
    integer i;
    integer errors;
    reg [15:0] internal_count;
    reg expected_pwm;

    // TESTS
    initial begin
        // Initializare semnale
        rst_n = 0;
        pwm_en = 0;
        period = 0;
        functions = 0;
        compare1 = 0;
        compare2 = 0;
        count_val = 0;

        #20 rst_n = 1;

        // ==== TEST 1: Scriere PERIOD ====
        period = 16'h00FF;
        do_overflow(period);
        #10;
        if (uut.active_period == 16'h00FF)
            $display("TEST 1 (PERIOD write) PASSED");
        else
            $display("TEST 1 (PERIOD write) FAILED: got %h", uut.active_period);

        // ==== TEST 2: Activare PWM_EN ====
        pwm_en = 1;
        #10;
        if (pwm_en == 1)
            $display("TEST 2 (PWM_EN) PASSED");
        else
            $display("TEST 2 (PWM_EN) FAILED");

        // ==== TEST 3: FUNCTIONS Left aligned ====
        functions = 8'b0000_0000; // left aligned, aligned_mode=0
        do_overflow(period);
        #10;
        if (uut.active_align_left_right == 0 && uut.active_aligned_mode == 0)
            $display("TEST 3 (FUNCTIONS left aligned) PASSED");
        else
            $display("TEST 3 (FUNCTIONS left aligned) FAILED");

        // ==== TEST 4: FUNCTIONS Right aligned ====
        functions = 8'b0000_0001; // right aligned, aligned_mode=0
        do_overflow(period);
        #10;
        if (uut.active_align_left_right == 1 && uut.active_aligned_mode == 0)
            $display("TEST 4 (FUNCTIONS right aligned) PASSED");
        else
            $display("TEST 4 (FUNCTIONS right aligned) FAILED");

        // ==== TEST 5: Nealigned mode ====
        functions = 8'b0000_0010; // aligned_mode=1
        compare1 = 16'h0003;
        compare2 = 16'h0007;
        do_overflow(period);
        #10;
        if (uut.active_aligned_mode == 1)
            $display("TEST 5 (unaligned mode) PASSED");
        else
            $display("TEST 5 (unaligned mode) FAILED");

        // ==== TEST 6: PWM Output Behavior ====
        period = 16'h000A;
        compare1 = 16'h0003;
        functions = 8'b0000_0000; // left aligned
        pwm_en = 1;

        // Trigger overflow
        count_val = period;
        #10;
        count_val = 0;
        #10;
        #10;  // ✅ ADAUGĂ ACEST DELAY EXTRA

        // Acum testul
        internal_count = 0;
        errors = 0;

        for (i = 0; i < 2*period; i = i + 1) begin
            count_val = internal_count;
            #10;

            if (internal_count < compare1)
                expected_pwm = 1;
            else
                expected_pwm = 0;

            if (pwm_out !== expected_pwm) begin
                $display("PWM ERROR at count_val=%0d: pwm_out=%b, expected=%b", 
                        internal_count, pwm_out, expected_pwm);
                errors = errors + 1;
            end

            internal_count = internal_count + 1;
            if (internal_count > period) begin
                count_val = period;
                #10;
                count_val = 0;
                #10;
                #10;  // ✅ ȘI AICI
                internal_count = 0;
            end
        end

        if (errors == 0)
            $display("TEST 6 (PWM output behavior) PASSED");
        else
            $display("TEST 6 (PWM output behavior) FAILED: %0d mismatches", errors);

        $finish;
    end

endmodule
