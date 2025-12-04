module unique_digits_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0][15:0] numbers,
    output reg [3:0][15:0] sorted_out,
    output reg [3:0] valid_mask
);

    function automatic logic is_valid(input [15:0] num);
        logic [4:0][3:0] digits;
        digits[4] = (num / 10000) % 10;
        digits[3] = (num / 1000) % 10;
        digits[2] = (num / 100) % 10;
        digits[1] = (num / 10) % 10;
        digits[0] = num % 10;
        return (digits[4][0] && digits[3][0] && digits[2][0] && digits[1][0] && digits[0][0]);
    endfunction

    localparam IDLE = 3'd0;
    localparam LOAD = 3'd1;
    localparam SORT1 = 3'd2;
    localparam SORT2 = 3'd3;
    localparam SORT3 = 3'd4;
    localparam DONE = 3'd5;

    reg [2:0] state;
    reg [3:0][15:0] input_reg;
    reg [3:0] valid_flags;
    reg [3:0][15:0] work_array;
    reg [2:0] val_cnt;
    reg [1:0] passes;

    always_comb begin
        valid_flags = 0;
        for (int i=0; i<4; i++) valid_flags[i] = is_valid(input_reg[i]);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            sorted_out <= 0;
            valid_mask <= 0;
            work_array <= 0;
            val_cnt <= 0;
            passes <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        input_reg <= numbers;
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    work_array <= 0;
                    val_cnt <= 0;
                    for (int i=0; i<4; i++) begin
                        if (valid_flags[i]) begin
                            work_array[val_cnt] <= input_reg[i];
                            val_cnt <= val_cnt + 1;
                        end
                    end
                    passes <= 0;
                    state <= SORT1;
                end
                SORT1, SORT2, SORT3: begin
                    passes <= passes + 1;
                    for (int i=0; i<3; i++) begin
                        if (i < val_cnt-1-passes) begin
                            if (work_array[i] > work_array[i+1]) begin
                                work_array[i] <= work_array[i+1];
                                work_array[i+1] <= work_array[i];
                            end
                        end
                    end
                    if (passes == 2) state <= DONE;
                    else state <= state + 1;
                end
                DONE: begin
                    sorted_out <= work_array;
                    valid_mask <= (1 << val_cnt) - 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule