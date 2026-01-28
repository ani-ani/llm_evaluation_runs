module safe_rocket(
    input [1:0] size_a,
    input [7:0] ax0, ay0,
    input [7:0] ax1, ay1,
    input [7:0] ax2, ay2,
    input [7:0] ax3, ay3,
    input [1:0] size_b,
    input [7:0] bx0, by0,
    input [7:0] bx1, by1,
    input [7:0] bx2, by2,
    input [7:0] bx3, by3,
    output reg safe
);

    reg [17:0] len2_a [0:3];
    reg [17:0] len2_b [0:3];
    reg signed [17:0] dot_a [0:3];
    reg signed [17:0] dot_b [0:3];
    reg signed [17:0] cross_a [0:3];
    reg signed [17:0] cross_b [0:3];

    reg [8:0] wx_a [0:3];
    reg [8:0] wy_a [0:3];
    reg [8:0] wx_b [0:3];
    reg [8:0] wy_b [0:3];

    reg [8:0] ex_a [0:3];
    reg [8:0] ey_a [0:3];
    reg [8:0] ex_b [0:3];
    reg [8:0] ey_b [0:3];

    integer i;
    reg match;

    always @(*) begin
        safe = 1'b0;
        
        if (size_a != size_b) begin
            safe = 1'b0;
        end else if (size_a == 2'd1) begin
            reg [17:0] dist_a;
            reg [17:0] dist_b;
            
            dist_a = ($signed(ax1) - $signed(ax0)) ** 2 + ($signed(ay1) - $signed(ay0)) ** 2;
            dist_b = ($signed(bx1) - $signed(bx0)) ** 2 + ($signed(by1) - $signed(by0)) ** 2;
            
            safe = (dist_a == dist_b);
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                wx_a[i] = 9'd0;
                wy_a[i] = 9'd0;
                wx_b[i] = 9'd0;
                wy_b[i] = 9'd0;
                ex_a[i] = 9'd0;
                ey_a[i] = 9'd0;
                ex_b[i] = 9'd0;
                ey_b[i] = 9'd0;
                len2_a[i] = 18'd0;
                len2_b[i] = 18'd0;
                dot_a[i] = 18'd0;
                dot_b[i] = 18'd0;
                cross_a[i] = 18'd0;
                cross_b[i] = 18'd0;
            end
            
            wx_a[0] = 9'd0;
            wy_a[0] = 9'd0;
            wx_b[0] = 9'd0;
            wy_b[0] = 9'd0;
            
            if (size_a >= 2'd2) begin
                wx_a[1] = $signed(ax1) - $signed(ax0);
                wy_a[1] = $signed(ay1) - $signed(ay0);
                wx_b[1] = $signed(bx1) - $signed(bx0);
                wy_b[1] = $signed(by1) - $signed(by0);
            end
            
            if (size_a >= 2'd3) begin
                wx_a[2] = $signed(ax2) - $signed(ax0);
                wy_a[2] = $signed(ay2) - $signed(ay0);
                wx_b[2] = $signed(bx2) - $signed(bx0);
                wy_b[2] = $signed(by2) - $signed(by0);
            end
            
            if (size_a == 2'd3) begin
                wx_a[3] = 9'd0;
                wy_a[3] = 9'd0;
                wx_b[3] = 9'd0;
                wy_b[3] = 9'd0;
            end else if (size_a == 2'd4) begin
                wx_a[3] = $signed(ax3) - $signed(ax0);
                wy_a[3] = $signed(ay3) - $signed(ay0);
                wx_b[3] = $signed(bx3) - $signed(bx0);
                wy_b[3] = $signed(by3) - $signed(by0);
            end
            
            for (i = 0; i < size_a; i = i + 1) begin
                ex_a[i] = wx_a[(i + 1) % size_a] - wx_a[i];
                ey_a[i] = wy_a[(i + 1) % size_a] - wy_a[i];
                ex_b[i] = wx_b[(i + 1) % size_a] - wx_b[i];
                ey_b[i] = wy_b[(i + 1) % size_a] - wy_b[i];
                
                len2_a[i] = ex_a[i] * ex_a[i] + ey_a[i] * ey_a[i];
                len2_b[i] = ex_b[i] * ex_b[i] + ey_b[i] * ey_b[i];
                
                dot_a[i] = ex_a[i] * ex_a[(i + 1) % size_a] + ey_a[i] * ey_a[(i + 1) % size_a];
                dot_b[i] = ex_b[i] * ex_b[(i + 1) % size_a] + ey_b[i] * ey_b[(i + 1) % size_a];
                
                cross_a[i] = ex_a[i] * ey_a[(i + 1) % size_a] - ey_a[i] * ex_a[(i + 1) % size_a];
                cross_b[i] = ex_b[i] * ey_b[(i + 1) % size_a] - ey_b[i] * ex_b[(i + 1) % size_a];
            end
            
            match = 1'b0;
            for (i = 0; i < size_a; i = i + 1) begin
                reg all_match;
                integer j;
                
                all_match = 1'b1;
                for (j = 0; j < size_a; j = j + 1) begin
                    if (len2_a[j] != len2_b[(j + i) % size_a] || dot_a[j] != dot_b[(j + i) % size_a] || cross_a[j] != cross_b[(j + i) % size_a]) begin
                        all_match = 1'b0;
                    end
                end
                
                if (all_match) begin
                    match = 1'b1;
                end
            end
            
            safe = match;
        end
    end
endmodule