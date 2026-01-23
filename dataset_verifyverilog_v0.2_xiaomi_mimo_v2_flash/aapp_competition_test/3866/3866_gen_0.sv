module lucky_permutation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [3:0] a_out,
    output reg [3:0] b_out,
    output reg [3:0] c_out,
    output reg [3:0] index_out,
    output reg valid,
    output reg done
);

    // Parameters
    parameter MAX_N = 16;

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [3:0] i; // Current index, 4 bits since n <= 16
    reg [3:0] n_reg; // Store n value
    reg [4:0] temp_c; // 5 bits to hold 2*i (max 30)

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            a_out <= 4'b0;
            b_out <= 4'b0;
            c_out <= 4'b0;
            index_out <= 4'b0;
            i <= 4'b0;
            n_reg <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        n_reg <= n_in[3:0]; // Truncate to 4 bits as n <= 16
                        i <= 4'b0;
                        index_out <= 4'b0;
                    end
                end

                PROCESSING: begin
                    valid <= 1'b1;
                    
                    // Compute a[i] and b[i]
                    a_out <= i;
                    b_out <= i;
                    
                    // Compute c[i] = (2*i) % n
                    // If 2*i < n, c = 2*i, else c = 2*i - n
                    temp_c = {1'b0, i} << 1; // 2*i, 5 bits
                    if (temp_c < n_reg) begin
                        c_out <= temp_c[3:0];
                    end else begin
                        c_out <= temp_c[3:0] - n_reg;
                    end
                    
                    // Increment index
                    index_out <= i;
                    
                    // Check for completion
                    if (i == n_reg - 1'b1) begin
                        state <= DONE;
                    end else begin
                        i <= i + 1'b1;
                    end
                end

                DONE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE; // Return to IDLE after done, or stay? Assuming self-return to IDLE for next start
                end
            endcase
        end
    end

endmodule
