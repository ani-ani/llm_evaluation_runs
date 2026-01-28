module adjacent_multiplier(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_in [0:3],
    output reg [47:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] MULTIPLY = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] temp_arr [0:3];
    reg [15:0] result_reg [0:2];
    integer i;

    // Combinational logic for multiplication
    wire [15:0] prod0;
    wire [15:0] prod1;
    wire [15:0] prod2;

    assign prod0 = temp_arr[0] * temp_arr[1];
    assign prod1 = temp_arr[1] * temp_arr[2];
    assign prod2 = temp_arr[2] * temp_arr[3];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 48'd0;
            for (i = 0; i < 4; i = i + 1) begin
                temp_arr[i] <= 8'd0;
            end
            for (i = 0; i < 3; i = i + 1) begin
                result_reg[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input array
                        for (i = 0; i < 4; i = i + 1) begin
                            temp_arr[i] <= arr_in[i];
                        end
                    end
                end
                
                MULTIPLY: begin
                    // Register multiplication results
                    result_reg[0] <= prod0;
                    result_reg[1] <= prod1;
                    result_reg[2] <= prod2;
                end
                
                COMPLETE: begin
                    // Pack results into 48-bit bus
                    result[15:0]   <= result_reg[0];
                    result[31:16]  <= result_reg[1];
                    result[47:32]  <= result_reg[2];
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
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                next_state = MULTIPLY;
            end
            
            MULTIPLY: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule