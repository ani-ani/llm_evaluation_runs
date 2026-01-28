module rolling_max_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done,
    output reg [3:0] position
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;

    reg [2:0] state, next_state;
    reg [3:0] current_pos;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd18;

    // Current maximum tracking
    reg signed [15:0] current_max;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_pos <= 4'd0;
            cycle_count <= 4'd0;
            current_max <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            position <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        current_pos <= 4'd0;
                        current_max <= arr[0];
                        result <= arr[0];
                        position <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Update current max
                    if (arr[current_pos] > current_max) begin
                        current_max <= arr[current_pos];
                    end
                    
                    // Output current result
                    result <= current_max;
                    position <= current_pos;
                    
                    // Assert done for one cycle
                    done <= 1'b1;
                    
                    // Move to next position or finish
                    if (current_pos == len - 1 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= PROCESS;
                        current_pos <= current_pos + 4'd1;
                        done <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule