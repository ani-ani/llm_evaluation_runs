module array_partitioning (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in,
    output reg [7:0] arr_even [0:15],
    output reg [7:0] arr_odd [0:15],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] CHECK_EVEN = 3'd2;
    localparam [2:0] CHECK_ODD = 3'd3;
    localparam [2:0] STORE_EVEN = 3'd4;
    localparam [2:0] STORE_ODD = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [4:0] index;           // 0-31 for 32 total inputs
    reg [4:0] even_ptr;        // Pointer for even array (0-15)
    reg [4:0] odd_ptr;         // Pointer for odd array (0-15)
    reg [7:0] temp_val;        // Store input value
    
    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            index <= 5'd0;
            even_ptr <= 5'd0;
            odd_ptr <= 5'd0;
            temp_val <= 8'd0;
            // Initialize all array elements to avoid X values
            arr_even[0] <= 8'd0; arr_even[1] <= 8'd0; arr_even[2] <= 8'd0; arr_even[3] <= 8'd0;
            arr_even[4] <= 8'd0; arr_even[5] <= 8'd0; arr_even[6] <= 8'd0; arr_even[7] <= 8'd0;
            arr_even[8] <= 8'd0; arr_even[9] <= 8'd0; arr_even[10] <= 8'd0; arr_even[11] <= 8'd0;
            arr_even[12] <= 8'd0; arr_even[13] <= 8'd0; arr_even[14] <= 8'd0; arr_even[15] <= 8'd0;
            arr_odd[0] <= 8'd0; arr_odd[1] <= 8'd0; arr_odd[2] <= 8'd0; arr_odd[3] <= 8'd0;
            arr_odd[4] <= 8'd0; arr_odd[5] <= 8'd0; arr_odd[6] <= 8'd0; arr_odd[7] <= 8'd0;
            arr_odd[8] <= 8'd0; arr_odd[9] <= 8'd0; arr_odd[10] <= 8'd0; arr_odd[11] <= 8'd0;
            arr_odd[12] <= 8'd0; arr_odd[13] <= 8'd0; arr_odd[14] <= 8'd0; arr_odd[15] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ_INPUT;
                        index <= 5'd0;
                        even_ptr <= 5'd0;
                        odd_ptr <= 5'd0;
                    end
                end
                
                READ_INPUT: begin
                    if (index < 5'd32) begin
                        temp_val <= in;
                        state <= CHECK_EVEN;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_EVEN: begin
                    // Check if value is even (LSB = 0)
                    if (temp_val[0] == 1'b0) begin
                        state <= STORE_EVEN;
                    end else begin
                        state <= CHECK_ODD;
                    end
                end
                
                CHECK_ODD: begin
                    // Value is odd (LSB = 1)
                    state <= STORE_ODD;
                end
                
                STORE_EVEN: begin
                    // Store in even array if there's space
                    if (even_ptr < 5'd16) begin
                        case (even_ptr)
                            5'd0: arr_even[0] <= temp_val;
                            5'd1: arr_even[1] <= temp_val;
                            5'd2: arr_even[2] <= temp_val;
                            5'd3: arr_even[3] <= temp_val;
                            5'd4: arr_even[4] <= temp_val;
                            5'd5: arr_even[5] <= temp_val;
                            5'd6: arr_even[6] <= temp_val;
                            5'd7: arr_even[7] <= temp_val;
                            5'd8: arr_even[8] <= temp_val;
                            5'd9: arr_even[9] <= temp_val;
                            5'd10: arr_even[10] <= temp_val;
                            5'd11: arr_even[11] <= temp_val;
                            5'd12: arr_even[12] <= temp_val;
                            5'd13: arr_even[13] <= temp_val;
                            5'd14: arr_even[14] <= temp_val;
                            5'd15: arr_even[15] <= temp_val;
                            default: arr_even[0] <= temp_val;
                        endcase
                        even_ptr <= even_ptr + 5'd1;
                    end
                    index <= index + 5'd1;
                    state <= READ_INPUT;
                end
                
                STORE_ODD: begin
                    // Store in odd array if there's space
                    if (odd_ptr < 5'd16) begin
                        case (odd_ptr)
                            5'd0: arr_odd[0] <= temp_val;
                            5'd1: arr_odd[1] <= temp_val;
                            5'd2: arr_odd[2] <= temp_val;
                            5'd3: arr_odd[3] <= temp_val;
                            5'd4: arr_odd[4] <= temp_val;
                            5'd5: arr_odd[5] <= temp_val;
                            5'd6: arr_odd[6] <= temp_val;
                            5'd7: arr_odd[7] <= temp_val;
                            5'd8: arr_odd[8] <= temp_val;
                            5'd9: arr_odd[9] <= temp_val;
                            5'd10: arr_odd[10] <= temp_val;
                            5'd11: arr_odd[11] <= temp_val;
                            5'd12: arr_odd[12] <= temp_val;
                            5'd13: arr_odd[13] <= temp_val;
                            5'd14: arr_odd[14] <= temp_val;
                            5'd15: arr_odd[15] <= temp_val;
                            default: arr_odd[0] <= temp_val;
                        endcase
                        odd_ptr <= odd_ptr + 5'd1;
                    end
                    index <= index + 5'd1;
                    state <= READ_INPUT;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule