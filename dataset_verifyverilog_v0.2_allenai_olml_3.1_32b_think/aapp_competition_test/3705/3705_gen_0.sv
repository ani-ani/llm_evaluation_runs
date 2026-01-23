module phone_numbers (
    input clk,
    input rst_n,
    input start,
    input [99:0] digit_vector,
    output reg [3:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam COUNTING = 3'd1;
localparam CALCULATING = 3'd2;
localparam DONE_STATE = 3'd3;

reg [2:0] state;
reg [6:0] bit_counter;
reg [3:0] count_of_eights;
reg [6:0] total_digits;
reg [4:0] wait_counter;
reg [3:0] result;
reg done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        bit_counter <=0;
        count_of_eights <=0;
        total_digits <=0;
        wait_counter <=0;
        result <=0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COUNTING;
                    bit_counter <=0;
                    count_of_eights <=0;
                    total_digits <=0;
                    wait_counter <=19;
                end
            end
            COUNTING: begin
                if (bit_counter < 100) begin
                    if (digit_vector[bit_counter]) begin
                        total_digits <= total_digits +1;
                        if (bit_counter %10 ==8) begin
                            count_of_eights <= count_of_eights +1;
                        end
                    end
                    bit_counter <= bit_counter +1;
                end else begin
                    state <= CALCULATING;
                end
            end
            CALCULATING: begin
                if (wait_counter >0) begin
                    wait_counter <= wait_counter -1;
                end else begin
                    if (total_digits >=11) begin
                        result <= min(count_of_eights, total_digits /11);
                    end else begin
                        result <= min(count_of_eights, 0);
                    end
                    done <=1;
                    state <= DONE_STATE;
                end
            end
            DONE_STATE: begin
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule