module pokenom_go(
    input clk,
    input rst_n,
    input start,
    input [1:0] query_type,
    input [3:0] u,
    input [3:0] v,
    output reg [63:0] result,
    output reg done
);

    // Constants
    localparam MOD = 64'd1000000007;
    localparam IDLE = 3'b000;
    localparam UPDATE = 3'b001;
    localparam SUM = 3'b010;
    localparam DONE = 3'b011;

    // State register
    reg [2:0] state;
    
    // Data storage (indices 1-8, use 9 deep array)
    reg [63:0] E [1:8];
    reg [63:0] E2 [1:8];
    
    // Loop and temporary registers
    reg [3:0] idx;
    reg [63:0] temp_E;
    reg [63:0] temp_E2;
    reg [63:0] mod_sum;
    reg [63:0] inv_len;
    
    // Lookup table for modular inverses of 1..8
    function [63:0] get_inv;
        input [3:0] len;
        begin
            case(len)
                4'd1: get_inv = 64'd1;
                4'd2: get_inv = 64'd500000004;
                4'd3: get_inv = 64'd333333336;
                4'd4: get_inv = 64'd250000002;
                4'd5: get_inv = 64'd400000003;
                4'd6: get_inv = 64'd166666668;
                4'd7: get_inv = 64'd142857144;
                4'd8: get_inv = 64'd125000001;
                default: get_inv = 64'd0;
            endcase
        end
    endfunction

    // State transition and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            // Reset arrays to 0
            for (integer i = 1; i <= 8; i = i + 1) begin
                E[i] <= 64'd0;
                E2[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (query_type == 2'b01) begin
                            // Type 1: Update
                            inv_len <= get_inv(v - u + 1);
                            idx <= u;
                            state <= UPDATE;
                        end else if (query_type == 2'b10) begin
                            // Type 2: Calculate Sum
                            mod_sum <= 64'd0;
                            idx <= 4'd1;
                            state <= SUM;
                        end
                    end
                end

                UPDATE: begin
                    // Update logic for box idx
                    // Old values are currently in E[idx] and E2[idx]
                    // We use the stored values for the calculation
                    
                    // E_new = E_old + inv_len
                    // E2_new = E2_old + 2*E_old + inv_len
                    
                    // We perform modulo arithmetic manually to keep 64-bit safe (inputs < MOD)
                    // temp_E = E[idx] + inv_len
                    temp_E <= (E[idx] + inv_len) % MOD;
                    // temp_E2 = E2[idx] + 2*E[idx] + inv_len
                    // We calculate 2*E[idx] + E2[idx] + inv_len
                    temp_E2 <= (E2[idx] + (E[idx] << 1) + inv_len) % MOD;
                    
                    // Check if done with range
                    if (idx == v) begin
                        // Last index, update and go to done (or wait for start low)
                        // Since update takes 1 cycle to calculate, we write back next cycle?
                        // Actually, let's write back immediately or use a state.
                        // To avoid combinational loop on RAM, we will write back in next cycle.
                        // But to handle single cycle updates properly, we can update registers directly.
                        // However, we need to be careful about dependencies.
                        // Let's update in this cycle logic and transition.
                        // Or simpler: Update index logic in this cycle, wait for next cycle to write back?
                        // No, standard seq logic: Next state logic updates registers.
                        // Let's write back to array and move to DONE.
                        E[idx] <= (E[idx] + inv_len) % MOD;
                        E2[idx] <= (E2[idx] + (E[idx] << 1) + inv_len) % MOD;
                        state <= DONE;
                    end else begin
                        // Update current index and increment
                        E[idx] <= (E[idx] + inv_len) % MOD;
                        E2[idx] <= (E2[idx] + (E[idx] << 1) + inv_len) % MOD;
                        idx <= idx + 1;
                        state <= UPDATE;
                    end
                end

                SUM: begin
                    // Accumulate E2[idx] into mod_sum
                    mod_sum <= (mod_sum + E2[idx]) % MOD;
                    
                    if (idx == 4'd8) begin
                        result <= (mod_sum + E2[idx]) % MOD;
                        state <= DONE;
                    end else begin
                        idx <= idx + 1;
                        state <= SUM;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule