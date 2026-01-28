module ParenRemover(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] input_string,
    input wire [3:0] input_len,
    output reg [63:0] output_string,
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] SCAN  = 2'd1;
    localparam [1:0] WRITE = 2'd2;
    localparam [1:0] DONE  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] scan_index;       // 0-7 for 8 characters
    reg [2:0] write_index;      // 0-7 for output position
    reg [63:0] filtered_string; // Internal buffer for filtered string
    reg paren_state;            // 0=normal, 1=inside parentheses
    reg [7:0] cycle_count;      // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scan_index <= 3'd0;
            write_index <= 3'd0;
            filtered_string <= 64'd0;
            paren_state <= 1'b0;
            output_string <= 64'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SCAN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Extract current character
                    reg [7:0] current_char;
                    case (scan_index)
                        3'd0: current_char = input_string[7:0];
                        3'd1: current_char = input_string[15:8];
                        3'd2: current_char = input_string[23:16];
                        3'd3: current_char = input_string[31:24];
                        3'd4: current_char = input_string[39:32];
                        3'd5: current_char = input_string[47:40];
                        3'd6: current_char = input_string[55:48];
                        3'd7: current_char = input_string[63:56];
                        default: current_char = 8'd0;
                    endcase

                    // Process character
                    if (current_char == 8'd'(') begin
                        paren_state <= 1'b1;
                    end else if (current_char == 8'd')') begin
                        paren_state <= 1'b0;
                    end else if (paren_state == 1'b0 && current_char != 8'd0) begin
                        // Add to filtered string
                        case (write_index)
                            3'd0: filtered_string[7:0] <= current_char;
                            3'd1: filtered_string[15:8] <= current_char;
                            3'd2: filtered_string[23:16] <= current_char;
                            3'd3: filtered_string[31:24] <= current_char;
                            3'd4: filtered_string[39:32] <= current_char;
                            3'd5: filtered_string[47:40] <= current_char;
                            3'd6: filtered_string[55:48] <= current_char;
                            3'd7: filtered_string[63:56] <= current_char;
                        endcase
                        write_index <= write_index + 3'd1;
                    end

                    // Move to next character or finish
                    if (scan_index == input_len - 1'b1 || scan_index == 3'd7) begin
                        next_state <= WRITE;
                    end else begin
                        scan_index <= scan_index + 3'd1;
                        next_state <= SCAN;
                    end
                end

                WRITE: begin
                    output_string <= filtered_string;
                    output_len <= write_index;
                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule