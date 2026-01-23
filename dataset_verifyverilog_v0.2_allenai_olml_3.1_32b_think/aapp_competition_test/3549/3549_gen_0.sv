module find_min_distance(input clk, input rst_n, input start, input [6:0] m1, m2, m3, input [6:0] x1, x2, x3, input [6:0] y1, y2, y3, output reg [19:0] result, output reg done, output reg found);
    // State machine states
    localparam IDLE = 2'b00;
    localparam SEARCH = 2'b01;
    localparam VERIFY = 2'b10;
    localparam FINISHED = 2'b11;

    reg [1:0] state;
    reg [19:0] z;                // Current candidate distance
    reg [2:0] signal_idx;        // Which signal to verify (0,1,2)
    reg [6:0] rem;               // Remainder for current signal
    reg [6:0] diff;              // Difference for comparison
    reg valid_flag;              // Flag if current signal valid

    // Combinational logic for modulo operation
    // Since m <= 100, z is bounded, we can compute z mod m by repeated subtraction
    reg [19:0] z_temp;
    reg [6:0] m_temp;
    wire [6:0] mod_result;

    // Simple modulo computation: z % m
    // Since z can be up to 1M and m up to 100, we need ~14000 subtractions max
    // But we do it sequentially: one subtraction per clock cycle
    reg mod_start;
    reg mod_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            found <= 0;
            z <= 0;
            result <= 0;
            mod_start <= 0;
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
                    // Try next candidate z
                    if (z < 20'd1000000) begin  // Search bound
                        signal_idx <= 0;
                        valid_flag <= 1;
                        state <= VERIFY;
                        mod_start <= 1;
                        z_temp <= z;
                        m_temp <= m1;
                    end else begin
                        // No solution found within bound
                        state <= FINISHED;
                    end
                end

                VERIFY: begin
                    mod_start <= 0;
                    // Check each signal's constraint
                    if (!mod_done) begin
                        // Wait for modulo computation
                    end else begin
                        rem <= mod_result;
                        case (signal_idx)
                            0: begin
                                if ($signed(rem) < $signed(x1 - y1) || $signed(rem) > $signed(x1 + y1)) begin
                                    valid_flag <= 0;
                                end
                                signal_idx <= 1;
                                z_temp <= z;
                                m_temp <= m2;
                                mod_start <= 1;
                            end
                            1: begin
                                if ($signed(rem) < $signed(x2 - y2) || $signed(rem) > $signed(x2 + y2)) begin
                                    valid_flag <= 0;
                                end
                                signal_idx <= 2;
                                z_temp <= z;
                                m_temp <= m3;
                                mod_start <= 1;
                            end
                            2: begin
                                if ($signed(rem) < $signed(x3 - y3) || $signed(rem) > $signed(x3 + y3)) begin
                                    valid_flag <= 0;
                                end
                                // All signals checked
                                if (valid_flag) begin
                                    result <= z;
                                    found <= 1;
                                    state <= FINISHED;
                                end else begin
                                    z <= z + 1;
                                    state <= SEARCH;
                                end
                            end
                        endcase
                    end
                end

                FINISHED: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // Modulo computation unit
    reg [19:0] sub_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod_done <= 1;
            sub_val <= 0;
        end else begin
            if (mod_start) begin
                sub_val <= z_temp;
                mod_done <= 0;
            end else if (!mod_done) begin
                if (sub_val >= m_temp) begin
                    sub_val <= sub_val - m_temp;
                end else begin
                    mod_done <= 1;
                end
            end
        end
    end

    assign mod_result = sub_val[6:0];

endmodule

// Note: This is a sequential implementation that uses a state machine
// to search for the smallest z. It may take many cycles (up to 1M iterations).
// For a faster combinational approach, we could use a parallel search structure
// but that would require much more hardware resources.