module elementwise_division(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] num [0:7],
    input wire signed [7:0] den [0:7],
    input wire [3:0] len,
    output reg signed [15:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    // Internal signals
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            for (integer i = 0; i < 8; i = i + 1) begin
                result[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        index <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute division for current index
                    if (den[index] != 8'd0) begin
                        // Scaled division: (num * 256) / den
                        result[index] <= ($signed(num[index]) * 16'd256) / $signed(den[index]);
                    end else begin
                        result[index] <= 16'd0;  // Clamp to 0 for division by zero
                    end
                    
                    // Move to next index or finish
                    if (index == len - 1 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        index <= index + 3'd1;
                        next_state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule