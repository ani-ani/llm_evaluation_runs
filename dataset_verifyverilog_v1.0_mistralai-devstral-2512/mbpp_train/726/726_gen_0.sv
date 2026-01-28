module AdjacentMultiplier(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in [0:3],
    output reg [47:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Internal registers for computation
    reg [7:0] arr_reg [0:3];
    reg [15:0] mult_results [0:2];

    // Combinational multiplication
    wire [15:0] mult0 = arr_reg[0] * arr_reg[1];
    wire [15:0] mult1 = arr_reg[1] * arr_reg[2];
    wire [15:0] mult2 = arr_reg[2] * arr_reg[3];

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            mult_results[0] <= 16'd0;
            mult_results[1] <= 16'd0;
            mult_results[2] <= 16'd0;
            result <= 48'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                LOAD: begin
                    // Load input array
                    arr_reg[0] <= arr_in[0];
                    arr_reg[1] <= arr_in[1];
                    arr_reg[2] <= arr_in[2];
                    arr_reg[3] <= arr_in[3];
                    cycle_count <= cycle_count + 8'd1;
                end
                
                COMPUTE: begin
                    // Store multiplication results
                    mult_results[0] <= mult0;
                    mult_results[1] <= mult1;
                    mult_results[2] <= mult2;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                DONE_STATE: begin
                    // Pack results into output
                    result[15:0] <= mult_results[0];
                    result[31:16] <= mult_results[1];
                    result[47:32] <= mult_results[2];
                    done <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule