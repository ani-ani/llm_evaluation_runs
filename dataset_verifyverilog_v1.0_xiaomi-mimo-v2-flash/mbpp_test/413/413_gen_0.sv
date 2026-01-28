module extract_nth_element (
    input clk,
    input rst_n,
    input start,
    input [79:0] data_in,
    input [1:0] n,
    input [1:0] len,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [1:0] count;
    reg [1:0] count_next;
    
    // Combinational logic for extraction
    reg [7:0] extracted_byte;
    always @(*) begin
        case (n)
            2'd0: extracted_byte = data_in[7:0];       // ASCII char (byte 0)
            2'd1: extracted_byte = data_in[15:8];      // score1
            2'd2: extracted_byte = data_in[23:16];     // score2
            default: extracted_byte = data_in[7:0];    // Default to string
        endcase
    end
    
    // State transition logic
    always @(*) begin
        next_state = state;
        count_next = count;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = EXTRACT;
                    count_next = 2'd0;
                end
            end
            
            EXTRACT: begin
                if (count >= len) begin
                    next_state = DONE;
                end
                count_next = count + 2'd1;
            end
            
            DONE: begin
                next_state = IDLE;
                count_next = 2'd0;
            end
            
            default: begin
                next_state = IDLE;
                count_next = 2'd0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 2'd0;
            data_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= count_next;
            
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                end
                
                EXTRACT: begin
                    data_out <= extracted_byte;
                    valid_out <= 1'b1;
                    done <= 1'b0;
                end
                
                DONE: begin
                    valid_out <= 1'b0;
                    done <= 1'b1;
                end
                
                default: begin
                    data_out <= 8'd0;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule