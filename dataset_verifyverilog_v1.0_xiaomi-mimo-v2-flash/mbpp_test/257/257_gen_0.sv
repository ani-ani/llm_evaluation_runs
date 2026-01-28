module swap_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] result_a,
    output reg [7:0] result_b,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] captured_a, captured_b;
    reg [1:0] cycle_count;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            captured_a <= 8'd0;
            captured_b <= 8'd0;
            result_a <= 8'd0;
            result_b <= 8'd0;
            done <= 1'b0;
            cycle_count <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 2'd0;
                    if (start) begin
                        captured_a <= a;
                        captured_b <= b;
                    end
                end
                
                PROCESS: begin
                    result_a <= captured_b;
                    result_b <= captured_a;
                    cycle_count <= cycle_count + 2'd1;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule