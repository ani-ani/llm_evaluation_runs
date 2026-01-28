module ModuloArrayProcessor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1_in [0:7],
    input wire [7:0] arr2_in [0:7],
    input wire [3:0] len,
    output reg [7:0] result_out [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [3:0] counter;
    reg [7:0] temp_result;
    
    // Combinational divider for modulo operation
    // Since arr2_in[i] is guaranteed non-zero, no division by zero check needed
    wire [7:0] modulo_result;
    assign modulo_result = arr1_in[counter] % arr2_in[counter];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            temp_result <= 8'd0;
            // Initialize all output array elements
            result_out[0] <= 8'd0;
            result_out[1] <= 8'd0;
            result_out[2] <= 8'd0;
            result_out[3] <= 8'd0;
            result_out[4] <= 8'd0;
            result_out[5] <= 8'd0;
            result_out[6] <= 8'd0;
            result_out[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Perform modulo operation for current index
                    temp_result <= modulo_result;
                    
                    // Store result in output array at current counter position
                    case (counter)
                        4'd0: result_out[0] <= modulo_result;
                        4'd1: result_out[1] <= modulo_result;
                        4'd2: result_out[2] <= modulo_result;
                        4'd3: result_out[3] <= modulo_result;
                        4'd4: result_out[4] <= modulo_result;
                        4'd5: result_out[5] <= modulo_result;
                        4'd6: result_out[6] <= modulo_result;
                        4'd7: result_out[7] <= modulo_result;
                        default: begin
                            result_out[0] <= result_out[0];
                            result_out[1] <= result_out[1];
                            result_out[2] <= result_out[2];
                            result_out[3] <= result_out[3];
                            result_out[4] <= result_out[4];
                            result_out[5] <= result_out[5];
                            result_out[6] <= result_out[6];
                            result_out[7] <= result_out[7];
                        end
                    endcase
                    
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Check if we've processed all elements (len cycles)
                    if (counter == (len - 4'd1)) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule