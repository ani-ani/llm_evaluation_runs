module rotator_32bit_left (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] data_in,
    input wire [4:0] shift_amount,
    output reg [31:0] data_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [31:0] captured_data;
    reg [4:0] captured_amount;
    reg [31:0] result_reg;
    
    // Combinational logic for rotation
    wire [31:0] shift_left;
    wire [31:0] shift_right;
    wire [31:0] rotation_result;
    
    // Left shift
    assign shift_left = captured_data << captured_amount;
    // Right shift (32 - amount)
    assign shift_right = captured_data >> (32 - captured_amount);
    // Combine
    assign rotation_result = shift_left | shift_right;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            data_out <= 32'd0;
            captured_data <= 32'd0;
            captured_amount <= 5'd0;
            result_reg <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        captured_data <= data_in;
                        captured_amount <= shift_amount;
                    end
                end
                
                COMPUTE: begin
                    // Compute rotation
                    result_reg <= rotation_result;
                end
                
                OUTPUT: begin
                    data_out <= result_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule