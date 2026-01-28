module cyclic_shift_min_dev(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] p [0:7],
    input wire [3:0] n,
    output reg [15:0] min_dev,
    output reg [3:0] best_shift,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Counters and registers
    reg [3:0] shift_count;
    reg [3:0] pos_count;
    reg [15:0] current_dev;
    reg [15:0] temp_dev;
    reg [7:0] mod_result;
    reg [7:0] diff;
    reg [7:0] abs_diff;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            shift_count <= 4'd0;
            pos_count <= 4'd0;
            current_dev <= 16'd0;
            temp_dev <= 16'd0;
            mod_result <= 8'd0;
            diff <= 8'd0;
            abs_diff <= 8'd0;
            min_dev <= 16'd0;
            best_shift <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        shift_count <= 4'd0;
                        pos_count <= 4'd0;
                        current_dev <= 16'd0;
                        temp_dev <= 16'd0;
                        min_dev <= 16'd0;
                        best_shift <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate modulo: (pos_count + shift_count) mod n
                    if (pos_count + shift_count < n) begin
                        mod_result <= pos_count + shift_count;
                    end else begin
                        mod_result <= (pos_count + shift_count) - n;
                    end
                    
                    // Calculate absolute difference
                    if (p[pos_count] > mod_result) begin
                        abs_diff <= p[pos_count] - mod_result;
                    end else begin
                        abs_diff <= mod_result - p[pos_count];
                    end
                    
                    // Accumulate deviation for current shift
                    temp_dev <= temp_dev + abs_diff;
                    
                    // Move to next position
                    if (pos_count == n - 1) begin
                        // Compare with minimum
                        if (temp_dev < min_dev || min_dev == 16'd0) begin
                            min_dev <= temp_dev;
                            best_shift <= shift_count;
                        end
                        
                        // Move to next shift
                        shift_count <= shift_count + 4'd1;
                        pos_count <= 4'd0;
                        temp_dev <= 16'd0;
                        
                        // Check if all shifts done
                        if (shift_count == n - 1 || cycle_count >= MAX_CYCLES) begin
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        pos_count <= pos_count + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule