module substitution_decoder #(
    parameter MAX_LEN = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] encrypted_text [0:MAX_LEN-1],
    input wire [7:0] mapping [0:25],
    output reg [7:0] decrypted_text [0:MAX_LEN-1],
    output reg done
);
    // Internal state declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISHED = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] counter;
    reg [7:0] index;
    
    integer i;

    // State transition logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESSING: begin
                if (counter >= MAX_LEN) begin
                    next_state = FINISHED;
                end else begin
                    next_state = PROCESSING;
                end
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            index <= 8'd0;
            done <= 1'b0;
            // Initialize all output array elements
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                decrypted_text[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    index <= 8'd0;
                end
                
                PROCESSING: begin
                    if (counter < MAX_LEN) begin
                        // Process current character
                        if (encrypted_text[counter] == 8'h20) begin
                            decrypted_text[counter] <= 8'h20;
                        end else if (encrypted_text[counter] >= 8'h61 && encrypted_text[counter] <= 8'h7a) begin
                            // Map lowercase letter
                            index <= encrypted_text[counter] - 8'h61;
                            decrypted_text[counter] <= mapping[encrypted_text[counter] - 8'h61];
                        end else begin
                            // Invalid character, replace with space
                            decrypted_text[counter] <= 8'h20;
                        end
                        counter <= counter + 8'd1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // Default case handled by state transition
                end
            endcase
        end
    end
endmodule