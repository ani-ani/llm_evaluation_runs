module extract_negatives(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_i [0:7],
    input wire [3:0] len_i,
    output reg signed [7:0] arr_o [0:7],
    output reg [3:0] len_o,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    reg [3:0] index;
    reg [3:0] neg_count;
    reg [3:0] output_index;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            index <= 4'd0;
            neg_count <= 4'd0;
            output_index <= 4'd0;
            done <= 1'b0;
            len_o <= 4'd0;
            
            // Initialize output array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                arr_o[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    neg_count <= 4'd0;
                    output_index <= 4'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is negative
                    if (arr_i[index] < 8'sd0) begin
                        arr_o[output_index] <= arr_i[index];
                        output_index <= output_index + 4'd1;
                        neg_count <= neg_count + 4'd1;
                    end
                    
                    // Move to next index
                    index <= index + 4'd1;
                    
                    // Check if processing is complete
                    if (index >= len_i || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    len_o <= neg_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule