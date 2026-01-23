module find_min_distance(
    input clk,
    input rst_n,
    input start,
    input [6:0] m1, m2, m3,      // Moduli (max 100)
    input [6:0] x1, x2, x3,      // Measurements (max 99)
    input [6:0] y1, y2, y3,      // Accuracies (max 100)
    output reg [19:0] result,    // Smallest z (0 to 1M)
    output reg done,
    output reg found
);

    // State machine states
    localparam IDLE = 3'b000;
    localparam SEARCH = 3'b001;
    localparam VERIFY_S1 = 3'b010;
    localparam VERIFY_S2 = 3'b011;
    localparam VERIFY_S3 = 3'b100;
    localparam NEXT_Z = 3'b101;
    localparam FINISHED = 3'b110;
    
    reg [2:0] state;
    reg [19:0] z;                // Current candidate distance
    reg [6:0] rem;               // Remainder for current signal
    reg valid_flag;              // Flag if current signal valid
    
    // Modulo computation registers
    reg [19:0] mod_z;
    reg [6:0] mod_m;
    reg [19:0] mod_temp;
    reg mod_calc_done;
    
    // Combinational signals for range check
    wire signed [7:0] x1_signed = {1'b0, x1};
    wire signed [7:0] y1_signed = {1'b0, y1};
    wire signed [7:0] x2_signed = {1'b0, x2};
    wire signed [7:0] y2_signed = {1'b0, y2};
    wire signed [7:0] x3_signed = {1'b0, x3};
    wire signed [7:0] y3_signed = {1'b0, y3};
    wire signed [7:0] rem_signed = {1'b0, rem};
    
    wire signed [7:0] low1 = x1_signed - y1_signed;
    wire signed [7:0] high1 = x1_signed + y1_signed;
    wire signed [7:0] low2 = x2_signed - y2_signed;
    wire signed [7:0] high2 = x2_signed + y2_signed;
    wire signed [7:0] low3 = x3_signed - y3_signed;
    wire signed [7:0] high3 = x3_signed + y3_signed;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            found <= 0;
            z <= 0;
            result <= 0;
            valid_flag <= 0;
            mod_calc_done <= 1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    found <= 0;
                    z <= 0;
                    if (start) begin
                        state <= SEARCH;
                        z <= 0;
                    end
                end
                
                SEARCH: begin
                    if (z < 20'd1000000) begin
                        // Start modulo computation for m1
                        mod_z <= z;
                        mod_m <= m1;
                        mod_temp <= z;
                        mod_calc_done <= 0;
                        valid_flag <= 1;
                        state <= VERIFY_S1;
                    end else begin
                        state <= FINISHED;
                    end
                end
                
                VERIFY_S1: begin
                    if (!mod_calc_done) begin
                        if (mod_temp >= mod_m) begin
                            mod_temp <= mod_temp - mod_m;
                        end else begin
                            mod_calc_done <= 1;
                            rem <= mod_temp[6:0];
                        end
                    end else begin
                        // Check range for signal 1
                        if (rem_signed < low1 || rem_signed > high1) begin
                            valid_flag <= 0;
                        end
                        // Start modulo for m2
                        mod_z <= z;
                        mod_m <= m2;
                        mod_temp <= z;
                        mod_calc_done <= 0;
                        state <= VERIFY_S2;
                    end
                end
                
                VERIFY_S2: begin
                    if (!mod_calc_done) begin
                        if (mod_temp >= mod_m) begin
                            mod_temp <= mod_temp - mod_m;
                        end else begin
                            mod_calc_done <= 1;
                            rem <= mod_temp[6:0];
                        end
                    end else begin
                        // Check range for signal 2
                        if (rem_signed < low2 || rem_signed > high2) begin
                            valid_flag <= 0;
                        end
                        // Start modulo for m3
                        mod_z <= z;
                        mod_m <= m3;
                        mod_temp <= z;
                        mod_calc_done <= 0;
                        state <= VERIFY_S3;
                    end
                end
                
                VERIFY_S3: begin
                    if (!mod_calc_done) begin
                        if (mod_temp >= mod_m) begin
                            mod_temp <= mod_temp - mod_m;
                        end else begin
                            mod_calc_done <= 1;
                            rem <= mod_temp[6:0];
                        end
                    end else begin
                        // Check range for signal 3
                        if (rem_signed < low3 || rem_signed > high3) begin
                            valid_flag <= 0;
                        end
                        // Check if valid
                        if (valid_flag) begin
                            result <= z;
                            found <= 1;
                            state <= FINISHED;
                        end else begin
                            state <= NEXT_Z;
                        end
                    end
                end
                
                NEXT_Z: begin
                    z <= z + 1;
                    state <= SEARCH;
                end
                
                FINISHED: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule