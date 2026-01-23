module list_flattener (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire valid_in,
    input wire [1:0] depth_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // Parameters
    localparam [3:0] MAX_ELEMENTS = 4'd15;
    localparam [2:0] DATA_WIDTH = 3'd8;
    localparam [3:0] RESULT_WIDTH = 4'd16;
    localparam [1:0] DEPTH_WIDTH = 2'd2;

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] WAIT_START = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] FINISH     = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] element_count;
    reg [15:0] sum_reg;
    reg [15:0] temp_result;
    reg processing_done;
    reg [7:0] temp_data;
    reg [1:0] temp_depth;
    reg valid_hold;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            element_count <= 4'd0;
            sum_reg <= 16'd0;
            temp_result <= 16'd0;
            processing_done <= 1'b0;
            temp_data <= 8'd0;
            temp_depth <= 2'd0;
            valid_hold <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize for new operation
                    ready <= 1'b1;
                    done <= 1'b0;
                    element_count <= 4'd0;
                    sum_reg <= 16'd0;
                    temp_result <= 16'd0;
                    processing_done <= 1'b0;
                    valid_hold <= 1'b0;
                    
                    if (start) begin
                        state <= WAIT_START;
                        ready <= 1'b0;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                WAIT_START: begin
                    // Wait for first valid input
                    if (valid_in) begin
                        // Capture first element
                        temp_data <= data_in;
                        temp_depth <= depth_in;
                        valid_hold <= 1'b1;
                        element_count <= 4'd1;
                        
                        // Add to sum if depth >= 1
                        if (depth_in >= 2'd1) begin
                            sum_reg <= 16'd0 + {8'd0, data_in};
                        end else begin
                            sum_reg <= 16'd0;
                        end
                        
                        state <= PROCESSING;
                    end else if (!valid_in) begin
                        // Empty sequence, go to finish
                        state <= FINISH;
                        processing_done <= 1'b1;
                    end else begin
                        state <= WAIT_START;
                    end
                end
                
                PROCESSING: begin
                    if (valid_in) begin
                        // Process new valid element
                        if (depth_in >= 2'd1) begin
                            sum_reg <= sum_reg + {8'd0, data_in};
                        end
                        
                        element_count <= element_count + 4'd1;
                        
                        // Check if reached max elements
                        if (element_count >= MAX_ELEMENTS) begin
                            processing_done <= 1'b1;
                            state <= FINISH;
                            temp_result <= sum_reg + {8'd0, data_in};
                        end else begin
                            state <= PROCESSING;
                        end
                    end else begin
                        // valid_in = 0, sequence ended
                        processing_done <= 1'b1;
                        state <= FINISH;
                        temp_result <= sum_reg;
                    end
                end
                
                FINISH: begin
                    // Output result and assert done
                    result <= temp_result;
                    done <= 1'b1;
                    ready <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule