module parity_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    input [7:0] n,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ROTATE  = 2'd1;
    localparam [1:0] COUNT   = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] rotated_string;
    reg [7:0] rotation_count;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rotated_string <= 8'd0;
            rotation_count <= 8'd0;
            cycle_counter <= 8'd0;
            result <= 5'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        rotated_string <= s;
                        rotation_count <= n;
                        next_state <= ROTATE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                ROTATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Perform left rotation
                    rotated_string <= {rotated_string[6:0], rotated_string[7]};
                    rotation_count <= rotation_count - 8'd1;
                    
                    // Check if all rotations are done
                    if (rotation_count == 8'd0 || cycle_counter >= MAX_CYCLES) begin
                        next_state <= COUNT;
                    end else begin
                        next_state <= ROTATE;
                    end
                end

                COUNT: begin
                    // Count number of 1's in rotated_string
                    result <= rotated_string[0] + rotated_string[1] + 
                             rotated_string[2] + rotated_string[3] + 
                             rotated_string[4] + rotated_string[5] + 
                             rotated_string[6] + rotated_string[7];
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 5'd0;
                end
            endcase
        end
    end
endmodule