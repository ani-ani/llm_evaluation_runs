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
    
    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] counter;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 8'd0;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                decrypted_text[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (counter < MAX_LEN) begin
                        if (encrypted_text[counter] == 8'h20) begin
                            decrypted_text[counter] <= 8'h20;
                        end else if ((encrypted_text[counter] >= 8'h61) && (encrypted_text[counter] <= 8'h7a)) begin
                            decrypted_text[counter] <= mapping[encrypted_text[counter] - 8'h61];
                        end else begin
                            decrypted_text[counter] <= 8'h20;
                        end
                        counter <= counter + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule