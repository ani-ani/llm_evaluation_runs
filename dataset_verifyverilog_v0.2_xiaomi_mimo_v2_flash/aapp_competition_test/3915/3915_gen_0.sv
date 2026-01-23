module prime_palindrome_solver (
    input clk,
    input rst_n,
    input start,
    input [13:0] p,
    input [13:0] q,
    output reg [9:0] result,
    output reg done,
    output reg no_solution
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam SIEVE_INIT = 3'b001;
    localparam SIEVE_PROCESS = 3'b010;
    localparam CALCULATE_ITER = 3'b011;
    localparam FINISHED = 3'b100;

    reg [2:0] state;
    reg [9:0] n;
    reg [9:0] i;
    reg [9:0] j;
    reg [9:0] sieve_base;
    reg sieve_phase;

    reg [9:0] prime_cnt;
    reg [9:0] rub_cnt;

    // Sieve RAM - 1024 x 1 bit
    reg prime_ram [1023:0];
    reg ram_wren;
    reg [9:0] ram_wr_addr;
    reg ram_wr_val;

    // RAM Write Logic
    always @(posedge clk) begin
        if (ram_wren) begin
            prime_ram[ram_wr_addr] <= ram_wr_val;
        end
    end

    // Palindrome Logic
    wire is_palindrome;
    reg [3:0] d0, d1, d2, d3;
    always @(*) begin
        integer temp;
        temp = n;
        d0 = 0; d1 = 0; d2 = 0; d3 = 0;
        if (temp >= 1000) begin d3 = 1; temp = temp - 1000; end
        if (temp >= 900) begin d2 = 9; temp = temp - 900; end
        else if (temp >= 800) begin d2 = 8; temp = temp - 800; end
        else if (temp >= 700) begin d2 = 7; temp = temp - 700; end
        else if (temp >= 600) begin d2 = 6; temp = temp - 600; end
        else if (temp >= 500) begin d2 = 5; temp = temp - 500; end
        else if (temp >= 400) begin d2 = 4; temp = temp - 400; end
        else if (temp >= 300) begin d2 = 3; temp = temp - 300; end
        else if (temp >= 200) begin d2 = 2; temp = temp - 200; end
        else if (temp >= 100) begin d2 = 1; temp = temp - 100; end
        if (temp >= 90) begin d1 = 9; temp = temp - 90; end
        else if (temp >= 80) begin d1 = 8; temp = temp - 80; end
        else if (temp >= 70) begin d1 = 7; temp = temp - 70; end
        else if (temp >= 60) begin d1 = 6; temp = temp - 60; end
        else if (temp >= 50) begin d1 = 5; temp = temp - 50; end
        else if (temp >= 40) begin d1 = 4; temp = temp - 40; end
        else if (temp >= 30) begin d1 = 3; temp = temp - 30; end
        else if (temp >= 20) begin d1 = 2; temp = temp - 20; end
        else if (temp >= 10) begin d1 = 1; temp = temp - 10; end
        d0 = temp;
    end
    assign is_palindrome = (n < 10) ? 1'b1 : (n < 100) ? (d1 == d0) : (n < 1000) ? (d2 == d0) : (d3 == d0) && (d2 == d1);

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            no_solution <= 1'b0;
            result <= 10'd0;
            prime_cnt <= 10'd0;
            rub_cnt <= 10'd0;
            ram_wren <= 1'b0;
            n <= 10'd0;
            i <= 10'd0;
            j <= 10'd0;
            sieve_base <= 10'd0;
            sieve_phase <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    no_solution <= 1'b0;
                    result <= 10'd0;
                    if (start) begin
                        state <= SIEVE_INIT;
                        i <= 10'd0;
                    end
                end

                SIEVE_INIT: begin
                    if (i > 1023) begin
                        state <= SIEVE_PROCESS;
                        i <= 10'd2;
                        sieve_phase <= 1'b0;
                        ram_wren <= 1'b0;
                    end else begin
                        ram_wren <= 1'b1;
                        ram_wr_addr <= i;
                        ram_wr_val = (i < 2) ? 1'b0 : 1'b1;
                        i <= i + 10'd1;
                    end
                end

                SIEVE_PROCESS: begin
                    if (sieve_phase == 1'b0) begin
                        if (i > 1023) begin
                            state <= CALCULATE_ITER;
                            n <= 10'd1;
                            ram_wren <= 1'b0;
                        end else if (i < 2) begin
                            i <= 10'd2;
                        end else begin
                            if (prime_ram[i] == 1'b1) begin
                                sieve_base <= i;
                                j <= i * 2;
                                sieve_phase <= 1'b1;
                                ram_wren <= 1'b1;
                                ram_wr_addr <= i * 2;
                                ram_wr_val = 1'b0;
                            end else begin
                                i <= i + 10'd1;
                            end
                        end
                    end else begin
                        j <= j + sieve_base;
                        if (j + sieve_base > 1023) begin
                            sieve_phase <= 1'b0;
                            ram_wren <= 1'b0;
                            i <= i + 10'd1;
                        end else begin
                            ram_wr_addr <= j + sieve_base;
                        end
                    end
                end

                CALCULATE_ITER: begin
                    if (n > 1023) begin
                        state <= FINISHED;
                        if (result == 10'd0) no_solution <= 1'b1;
                    end else begin
                        reg is_prime;
                        is_prime = prime_ram[n];

                        if (is_prime) prime_cnt <= prime_cnt + 10'd1;
                        if (is_palindrome) rub_cnt <= rub_cnt + 10'd1;

                        reg [23:0] lhs, rhs;
                        lhs = (prime_cnt + (is_prime ? 10'd1 : 10'd0)) * q;
                        rhs = (rub_cnt + (is_palindrome ? 10'd1 : 10'd0)) * p;

                        if (lhs <= rhs) begin
                            result <= n;
                        end

                        n <= n + 10'd1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Logic to drive ram_wr_val
    always @(*) begin
        if (state == SIEVE_INIT) begin
            ram_wr_val = (i < 2) ? 1'b0 : 1'b1;
        end else if (state == SIEVE_PROCESS && sieve_phase == 1'b1) begin
            ram_wr_val = 1'b0;
        end else begin
            ram_wr_val = 1'b0;
        end
    end

endmodule