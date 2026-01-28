module FindStrongestExtension (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] class_name,
    input wire [3:0] num_extensions,
    input wire [127:0] ext_name_i,
    input wire [3:0] ext_index,
    output reg [255:0] result_name,
    output reg signed [7:0] result_strength,
    output reg [3:0] result_index,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNTING = 3'd1;
    localparam [2:0] COMPARING = 3'd2;
    localparam [3:0] WAITING = 3'd3;
    localparam [3:0] DONE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] ext_counter;
    reg [3:0] char_counter;
    reg signed [7:0] current_strength;
    reg signed [7:0] best_strength;
    reg [3:0] best_idx;
    reg [127:0] best_ext;
    reg [7:0] cap_count;
    reg [7:0] sm_count;
    reg [7:0] current_char;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // For extracting characters from 128-bit packed string
    wire [7:0] class_chars [0:15];
    wire [7:0] ext_chars [0:15];
    
    // Unpack arrays (combinational)
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : unpack_class
            assign class_chars[i] = class_name[7 + 8*i : 8*i];
        end
        for (i = 0; i < 16; i = i + 1) begin : unpack_ext
            assign ext_chars[i] = ext_name_i[7 + 8*i : 8*i];
        end
    endgenerate

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COUNTING;
                else next_state = IDLE;
            end
            COUNTING: begin
                if (char_counter == 5'd15) next_state = COMPARING;
                else next_state = COUNTING;
            end
            COMPARING: begin
                next_state = WAITING;
            end
            WAITING: begin
                if (ext_counter >= num_extensions || cycle_count >= MAX_CYCLES) next_state = DONE;
                else next_state = COUNTING;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_name <= 256'd0;
            result_strength <= 8'sd0;
            result_index <= 4'd0;
            ext_counter <= 4'd0;
            char_counter <= 4'd0;
            current_strength <= 8'sd0;
            best_strength <= 8'sd0;
            best_idx <= 4'd0;
            best_ext <= 128'd0;
            cap_count <= 8'd0;
            sm_count <= 8'd0;
            current_char <= 8'd0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ext_counter <= 4'd0;
                    char_counter <= 4'd0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        best_strength <= 8'sd0;
                        best_idx <= 4'd0;
                        best_ext <= 128'd0;
                    end
                end
                
                COUNTING: begin
                    current_char <= ext_chars[char_counter];
                    
                    if (char_counter < 4'd15) begin
                        char_counter <= char_counter + 4'd1;
                    end else begin
                        char_counter <= 4'd0;
                    end
                end
                
                COMPARING: begin
                    // Count CAP and SM for current extension
                    if (current_char >= 8'd65 && current_char <= 8'd90) begin
                        cap_count <= cap_count + 8'd1;
                    end else if (current_char >= 8'd97 && current_char <= 8'd122) begin
                        sm_count <= sm_count + 8'd1;
                    end
                end
                
                WAITING: begin
                    // Update extension counter and cycle counter
                    ext_counter <= ext_counter + 4'd1;
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Calculate current strength
                    current_strength <= cap_count - sm_count;
                    
                    // Reset counters for next extension
                    cap_count <= 8'd0;
                    sm_count <= 8'd0;
                    
                    // Compare with best strength
                    if (cap_count - sm_count > best_strength) begin
                        best_strength <= cap_count - sm_count;
                        best_idx <= ext_counter;
                        best_ext <= ext_name_i;
                    end
                end
                
                DONE: begin
                    // Construct result string: class_name . best_ext
                    result_name <= {class_name, 8'd46, best_ext, 8'd0};
                    result_strength <= best_strength;
                    result_index <= best_idx;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule