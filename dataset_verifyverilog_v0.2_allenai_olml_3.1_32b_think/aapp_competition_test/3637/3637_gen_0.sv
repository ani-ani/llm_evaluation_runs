module pizza_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_friends,
    input [31:0] wishes [0:3],
    output reg found,
    output reg [7:0] selection
);

    reg [1:0] state;
    reg [7:0] current_subset;
    reg [7:0] selection_reg;
    reg found_reg;

    function automatic int check_valid;
        input int subset;
        input int num_friends;
        input [31:0] wishes [0:3];
        int i, j;
        int satisfied_count;
        int top;
        int type;
        int valid;
        valid = 1;
        for (i=0; i< num_friends; i=i+1) begin
            satisfied_count = 0;
            for (j=0; j<4; j=j+1) begin
                int wish_val;
                wish_val = wishes[i] >> (j*8) & 0xFF;
                top = wish_val & 0x07;
                type = (wish_val >> 3) & 1;
                if (type == 1) begin
                    if (subset & (1 << top)) satisfied_count = satisfied_count + 1;
                end else begin
                    if (!(subset & (1 << top))) satisfied_count = satisfied_count + 1;
                end
            end
            if (satisfied_count < 2) begin
                valid = 0;
                break;
            end
        end
        return valid;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'b00;
            current_subset <= 8'b0;
            selection_reg <= 8'b0;
            found_reg <= 1'b0;
        end else begin
            if (start) begin
                if (state == 2'b00) begin
                    state <= 2'b01;
                    current_subset <= 8'b0;
                end
            end
            if (state == 2'b01) begin
                current_subset <= current_subset + 1;
                if (check_valid(current_subset, num_friends, wishes)) begin
                    state <= 2'b10;
                    selection_reg <= current_subset;
                    found_reg <= 1'b1;
                end
            end
        end
    end

    assign found = found_reg;
    assign selection = selection_reg;

endmodule