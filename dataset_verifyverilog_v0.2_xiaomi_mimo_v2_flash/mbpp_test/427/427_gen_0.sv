module date_format_converter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State encoding
    localparam IDLE       = 5'd0;
    localparam READ_Y1    = 5'd1;
    localparam READ_Y2    = 5'd2;
    localparam READ_Y3    = 5'd3;
    localparam READ_Y4    = 5'd4;
    localparam SKIP_DASH1 = 5'd5;
    localparam READ_M1    = 5'd6;
    localparam READ_M2    = 5'd7;
    localparam SKIP_DASH2 = 5'd8;
    localparam READ_D1    = 5'd9;
    localparam READ_D2    = 5'd10;
    localparam OUTPUT_D2  = 5'd11;
    localparam OUTPUT_D1  = 5'd12;
    localparam OUTPUT_DASH1 = 5'd13;
    localparam OUTPUT_M2  = 5'd14;
    localparam OUTPUT_M1  = 5'd15;
    localparam OUTPUT_DASH2 = 5'd16;
    localparam OUTPUT_Y4  = 5'd17;
    localparam OUTPUT_Y3  = 5'd18;
    localparam OUTPUT_Y2  = 5'd19;
    localparam OUTPUT_Y1  = 5'd20;
    localparam DONE_STATE = 5'd21;

    reg [4:0] state, next_state;
    
    // Storage registers
    reg [7:0] y1, y2, y3, y4;
    reg [7:0] m1, m2;
    reg [7:0] d1, d2;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? READ_Y1 : IDLE;
            READ_Y1:    next_state = READ_Y2;
            READ_Y2:    next_state = READ_Y3;
            READ_Y3:    next_state = READ_Y4;
            READ_Y4:    next_state = SKIP_DASH1;
            SKIP_DASH1: next_state = READ_M1;
            READ_M1:    next_state = READ_M2;
            READ_M2:    next_state = SKIP_DASH2;
            SKIP_DASH2: next_state = READ_D1;
            READ_D1:    next_state = READ_D2;
            READ_D2:    next_state = OUTPUT_D2;
            OUTPUT_D2:  next_state = OUTPUT_D1;
            OUTPUT_D1:  next_state = OUTPUT_DASH1;
            OUTPUT_DASH1: next_state = OUTPUT_M2;
            OUTPUT_M2:  next_state = OUTPUT_M1;
            OUTPUT_M1:  next_state = OUTPUT_DASH2;
            OUTPUT_DASH2: next_state = OUTPUT_Y4;
            OUTPUT_Y4:  next_state = OUTPUT_Y3;
            OUTPUT_Y3:  next_state = OUTPUT_Y2;
            OUTPUT_Y2:  next_state = OUTPUT_Y1;
            OUTPUT_Y1:  next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_out <= 8'b0;
            out_valid <= 1'b0;
            done <= 1'b0;
            y1 <= 8'b0; y2 <= 8'b0; y3 <= 8'b0; y4 <= 8'b0;
            m1 <= 8'b0; m2 <= 8'b0;
            d1 <= 8'b0; d2 <= 8'b0;
        end else begin
            // Default assignments
            out_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                READ_Y1: begin
                    y1 <= char_in;
                end
                READ_Y2: begin
                    y2 <= char_in;
                end
                READ_Y3: begin
                    y3 <= char_in;
                end
                READ_Y4: begin
                    y4 <= char_in;
                end
                READ_M1: begin
                    m1 <= char_in;
                end
                READ_M2: begin
                    m2 <= char_in;
                end
                READ_D1: begin
                    d1 <= char_in;
                end
                READ_D2: begin
                    d2 <= char_in;
                end
                OUTPUT_D2: begin
                    char_out <= d2;
                    out_valid <= 1'b1;
                end
                OUTPUT_D1: begin
                    char_out <= d1;
                    out_valid <= 1'b1;
                end
                OUTPUT_DASH1: begin
                    char_out <= 8'h2D; // '-'
                    out_valid <= 1'b1;
                end
                OUTPUT_M2: begin
                    char_out <= m2;
                    out_valid <= 1'b1;
                end
                OUTPUT_M1: begin
                    char_out <= m1;
                    out_valid <= 1'b1;
                end
                OUTPUT_DASH2: begin
                    char_out <= 8'h2D; // '-'
                    out_valid <= 1'b1;
                end
                OUTPUT_Y4: begin
                    char_out <= y4;
                    out_valid <= 1'b1;
                end
                OUTPUT_Y3: begin
                    char_out <= y3;
                    out_valid <= 1'b1;
                end
                OUTPUT_Y2: begin
                    char_out <= y2;
                    out_valid <= 1'b1;
                end
                OUTPUT_Y1: begin
                    char_out <= y1;
                    out_valid <= 1'b1;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule