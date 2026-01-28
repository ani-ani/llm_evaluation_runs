module string_length_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_data_0,
    input wire [7:0] string_data_1,
    input wire [7:0] string_data_2,
    input wire [7:0] string_data_3,
    input wire [7:0] string_data_4,
    input wire [7:0] string_data_5,
    input wire [7:0] string_data_6,
    input wire [7:0] string_data_7,
    input wire [7:0] string_data_8,
    input wire [7:0] string_data_9,
    input wire [7:0] string_data_10,
    input wire [7:0] string_data_11,
    input wire [7:0] string_data_12,
    input wire [7:0] string_data_13,
    input wire [7:0] string_data_14,
    input wire [7:0] string_data_15,
    output reg [5:0] length,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SCANNING  = 2'd1;
    localparam [1:0] FINISH    = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] i;  // Counter for array index (0-15)
    reg [5:0] length_reg;  // Internal length register
    
    // Combinational logic for next state and outputs
    always @(*) begin
        next_state = IDLE;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCANNING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SCANNING: begin
                // Determine current byte value based on index
                case (i)
                    4'd0:  if (string_data_0 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd1:  if (string_data_1 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd2:  if (string_data_2 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd3:  if (string_data_3 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd4:  if (string_data_4 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd5:  if (string_data_5 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd6:  if (string_data_6 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd7:  if (string_data_7 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd8:  if (string_data_8 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd9:  if (string_data_9 == 8'd0)  next_state = FINISH; else next_state = SCANNING;
                    4'd10: if (string_data_10 == 8'd0) next_state = FINISH; else next_state = SCANNING;
                    4'd11: if (string_data_11 == 8'd0) next_state = FINISH; else next_state = SCANNING;
                    4'd12: if (string_data_12 == 8'd0) next_state = FINISH; else next_state = SCANNING;
                    4'd13: if (string_data_13 == 8'd0) next_state = FINISH; else next_state = SCANNING;
                    4'd14: if (string_data_14 == 8'd0) next_state = FINISH; else next_state = SCANNING;
                    4'd15: if (string_data_15 == 8'd0) next_state = FINISH; else next_state = FINISH;
                    default: next_state = SCANNING;
                endcase
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic for state transitions and registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            length_reg <= 6'd0;
            length <= 6'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 4'd0;
                        length_reg <= 6'd0;
                    end
                end
                
                SCANNING: begin
                    // Check if current character is null
                    case (i)
                        4'd0:  if (string_data_0 == 8'd0)  length_reg <= 6'd0;  else length_reg <= 6'd1;
                        4'd1:  if (string_data_1 == 8'd0)  length_reg <= 6'd1;  else length_reg <= 6'd2;
                        4'd2:  if (string_data_2 == 8'd0)  length_reg <= 6'd2;  else length_reg <= 6'd3;
                        4'd3:  if (string_data_3 == 8'd0)  length_reg <= 6'd3;  else length_reg <= 6'd4;
                        4'd4:  if (string_data_4 == 8'd0)  length_reg <= 6'd4;  else length_reg <= 6'd5;
                        4'd5:  if (string_data_5 == 8'd0)  length_reg <= 6'd5;  else length_reg <= 6'd6;
                        4'd6:  if (string_data_6 == 8'd0)  length_reg <= 6'd6;  else length_reg <= 6'd7;
                        4'd7:  if (string_data_7 == 8'd0)  length_reg <= 6'd7;  else length_reg <= 6'd8;
                        4'd8:  if (string_data_8 == 8'd0)  length_reg <= 6'd8;  else length_reg <= 6'd9;
                        4'd9:  if (string_data_9 == 8'd0)  length_reg <= 6'd9;  else length_reg <= 6'd10;
                        4'd10: if (string_data_10 == 8'd0) length_reg <= 6'd10; else length_reg <= 6'd11;
                        4'd11: if (string_data_11 == 8'd0) length_reg <= 6'd11; else length_reg <= 6'd12;
                        4'd12: if (string_data_12 == 8'd0) length_reg <= 6'd12; else length_reg <= 6'd13;
                        4'd13: if (string_data_13 == 8'd0) length_reg <= 6'd13; else length_reg <= 6'd14;
                        4'd14: if (string_data_14 == 8'd0) length_reg <= 6'd14; else length_reg <= 6'd15;
                        4'd15: if (string_data_15 == 8'd0) length_reg <= 6'd15; else length_reg <= 6'd16;
                        default: length_reg <= 6'd0;
                    endcase
                    
                    // Increment index if not null and not at max
                    if (i < 4'd15) begin
                        i <= i + 4'd1;
                    end
                end
                
                FINISH: begin
                    length <= length_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule