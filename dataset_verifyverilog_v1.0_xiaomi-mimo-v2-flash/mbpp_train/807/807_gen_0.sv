module FindFirstOdd (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SCANNING  = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] max_index;
    reg [7:0] current_element;
    reg [7:0] found_value;
    reg odd_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    // Combinational logic to select current array element
    always @(*) begin
        case (index)
            4'd0: current_element = arr_0;
            4'd1: current_element = arr_1;
            4'd2: current_element = arr_2;
            4'd3: current_element = arr_3;
            4'd4: current_element = arr_4;
            4'd5: current_element = arr_5;
            4'd6: current_element = arr_6;
            4'd7: current_element = arr_7;
            default: current_element = 8'd0;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            max_index <= 4'd0;
            found_value <= 8'd0;
            odd_found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    odd_found <= 1'b0;
                    index <= 4'd0;
                    
                    if (start) begin
                        // Clamp len to 1-8 range, default to 8 if invalid
                        if (len >= 4'd1 && len <= 4'd8) begin
                            max_index <= len;
                        end else begin
                            max_index <= 4'd8;
                        end
                        state <= SCANNING;
                    end
                end

                SCANNING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is odd
                    if (current_element[0] == 1'b1) begin
                        found_value <= current_element;
                        odd_found <= 1'b1;
                        result <= current_element;
                        state <= DONE;
                    end else begin
                        // Continue scanning
                        index <= index + 4'd1;
                        
                        // Check if we've checked all elements
                        if (index >= (max_index - 4'd1)) begin
                            // No odd found in array
                            if (!odd_found) begin
                                result <= 8'hFF;
                            end else begin
                                result <= found_value;
                            end
                            state <= DONE;
                        end
                        
                        // Safety timeout
                        if (cycle_count >= MAX_CYCLES) begin
                            result <= 8'hFF;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule