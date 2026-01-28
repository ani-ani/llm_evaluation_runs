module PokemonGCD(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] s_i,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state;
    reg [7:0] count;
    reg [7:0] max_count;
    reg [7:0] d;
    reg [7:0] m;
    reg [7:0] temp_sum;
    reg [7:0] freq [0:255];
    reg [7:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Initialize frequency table
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            max_count <= 8'd0;
            d <= 8'd0;
            m <= 8'd0;
            temp_sum <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
            cycle_count <= 12'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        state <= READ;
                        count <= 8'd0;
                    end
                end

                READ: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (count < n) begin
                        // Update frequency table
                        freq[s_i] <= (freq[s_i] == 8'd255) ? 8'd255 : freq[s_i] + 8'd1;
                        count <= count + 8'd1;
                    end else begin
                        state <= CALCULATE;
                        d <= 8'd2;
                        max_count <= 8'd0;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (d <= 8'd255) begin
                        temp_sum <= 8'd0;
                        m <= d;
                        // Sum multiples of d
                        while (m <= 8'd255) begin
                            temp_sum <= temp_sum + freq[m];
                            m <= m + d;
                        end
                        // Update max_count
                        if (temp_sum > max_count) begin
                            max_count <= temp_sum;
                        end
                        d <= d + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Ensure result is at least 1
                    result <= (max_count == 8'd0) ? 8'd1 : max_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule