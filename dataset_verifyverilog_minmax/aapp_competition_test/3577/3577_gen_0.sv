module plant_flowers(
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [7:0] L,
    input reg [7:0] R,
    output reg [4:0] num_flowers,
    output reg done
);
    // Internal signals
    logic [2:0] ptr;
    logic full;
    logic store_req;
    logic start_r;
    logic [7:0] next_L, next_R;
    logic [7:0] L_arr [0:7];
    logic [7:0] R_arr [0:7];

    // Reset and storage logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= 3'b0;
            full <= 1'b0;
            L_arr <= '{default:8'b0};
            R_arr <= '{default:8'b0};
            store_req <= 1'b0;
            start_r <= 1'b0;
            next_L <= 8'b0;
            next_R <= 8'b0;
            done <= 1'b0;
        end else begin
            start_r <= start;
            if (start && !start_r) begin
                next_L <= L;
                next_R <= R;
                store_req <= 1'b1;
            end
            if (store_req) begin
                if (!full) begin
                    L_arr[ptr] <= next_L;
                    R_arr[ptr] <= next_R;
                    if (ptr == 3'b111) full <= 1'b1;
                    ptr <= ptr + 1;
                end
                done <= 1'b1;
                store_req <= 1'b0;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Combinational computation of num_flowers
    always_comb begin
        int i;
        int cnt = 0;
        logic [3:0] stored_cnt;
        if (full) stored_cnt = 4'd8;
        else stored_cnt = {1'b0, ptr};
        for (i = 0; i < 8; i++) begin
            if (i < stored_cnt) begin
                if ((L > L_arr[i] && L < R_arr[i]) || (R > L_arr[i] && R < R_arr[i]))
                    cnt++;
            end
        end
        num_flowers = cnt;
    end

endmodule