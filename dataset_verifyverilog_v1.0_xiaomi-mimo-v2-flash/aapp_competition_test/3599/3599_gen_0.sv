module MusicalBreakScheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] t_in,
    input wire [9:0] n_in,
    input wire [15:0] b_in,
    input wire b_valid,
    output reg [15:0] s_out,
    output reg s_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SCHEDULE  = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Registers for input storage
    reg [15:0] T_reg;
    reg [9:0] N_reg;
    reg [15:0] current_b;
    reg [9:0] musician_idx;
    reg [15:0] current_time;
    reg [15:0] max_time;
    
    // Storage for scheduled breaks (max 500)
    reg [15:0] starts [0:499];
    reg [15:0] ends [0:499];
    reg [15:0] durations [0:499];
    
    // Active break counter and variables
    reg [2:0] active_count;
    reg [9:0] check_idx;
    reg [15:0] temp_start;
    reg [15:0] temp_end;
    reg overlap_flag;
    
    // State machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Helper wires
    wire [15:0] candidate_end;
    wire [15:0] search_limit;
    
    assign candidate_end = current_time + current_b;
    assign search_limit = T_reg - current_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            s_valid <= 1'b0;
            s_out <= 16'd0;
            musician_idx <= 10'd0;
            current_time <= 16'd0;
            current_b <= 16'd0;
            T_reg <= 16'd0;
            N_reg <= 10'd0;
            active_count <= 3'd0;
            check_idx <= 10'd0;
            overlap_flag <= 1'b0;
            temp_start <= 16'd0;
            temp_end <= 16'd0;
            // Initialize arrays (Icarus Verilog compatible)
            // Note: Synthesis tools will optimize this initial block
            // For simulation correctness with Icarus, we only reset state logic
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    s_valid <= 1'b0;
                    musician_idx <= 10'd0;
                    if (start) begin
                        T_reg <= t_in;
                        N_reg <= n_in;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (b_valid) begin
                        current_b <= b_in;
                        current_time <= 16'd0;
                        overlap_flag <= 1'b0;
                        state <= SCHEDULE;
                    end
                end
                
                SCHEDULE: begin
                    if (current_time <= search_limit) begin
                        // Start checking overlaps for this time slot
                        check_idx <= 10'd0;
                        active_count <= 3'd0;
                        overlap_flag <= 1'b0;
                        temp_start <= current_time;
                        temp_end <= candidate_end;
                        state <= CHECK;
                    end else begin
                        // No valid time found (should not happen per problem statement)
                        s_out <= 16'd0;
                        s_valid <= 1'b1;
                        musician_idx <= musician_idx + 10'd1;
                        state <= OUTPUT;
                    end
                end
                
                CHECK: begin
                    if (check_idx < musician_idx) begin
                        // Check if current time overlaps with scheduled break
                        // Overlap condition: start < temp_end && end > temp_start
                        if ((starts[check_idx] < temp_end) && (ends[check_idx] > temp_start)) begin
                            active_count <= active_count + 3'd1;
                        end
                        check_idx <= check_idx + 10'd1;
                    end else begin
                        // Finished checking all previous breaks
                        if (active_count < 3'd2) begin
                            // Valid slot found (0 or 1 overlap allowed)
                            starts[musician_idx] <= temp_start;
                            ends[musician_idx] <= temp_end;
                            durations[musician_idx] <= current_b;
                            s_out <= temp_start;
                            s_valid <= 1'b1;
                            musician_idx <= musician_idx + 10'd1;
                            state <= OUTPUT;
                        end else begin
                            // Try next time slot
                            current_time <= current_time + 16'd1;
                            state <= SCHEDULE;
                        end
                    end
                end
                
                OUTPUT: begin
                    s_valid <= 1'b0;
                    if (musician_idx >= N_reg) begin
                        state <= DONE;
                    end else begin
                        state <= LOAD;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule