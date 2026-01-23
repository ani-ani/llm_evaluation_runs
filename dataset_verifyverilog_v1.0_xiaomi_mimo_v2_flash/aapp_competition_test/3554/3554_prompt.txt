module three_headed_monkey (
    input [31:0] D,
    input [31:0] W,
    input [31:0] C,
    output real result
);

real F;
real L;
real deliverable_normalized;
real deliverable;
real T_n;
real T_i;
real R;
real target;
integer n;
real f;
real d1;
integer i;

always @(*) begin
    // Convert inputs to real
    F = $itor(W) / $itor(C);
    L = $itor(D) / $itor(C);

    if (F <= 1.0) begin
        if (F > L) begin
            deliverable_normalized = F - L;
        end else begin
            deliverable_normalized = 0.0;
        end
    end else begin
        n = $floor(F);
        f = F - $itor(n);
        d1 = f / (2.0 * $itor(n) + 1.0);

        // Compute T_n = sum_{k=1}^{n} 1/(2k-1)
        T_n = 0.0;
        for (i = 1; i <= n; i = i + 1) begin
            T_n = T_n + 1.0 / (2.0 * $itor(i) - 1.0);
        end

        if (L >= d1 + T_n) begin
            deliverable_normalized = 0.0;
        end else begin
            R = L - d1;
            target = T_n - R;

            // Find smallest i>=1 such that T_i >= target
            T_i = 0.0;
            i = 0;
            while (T_i < target) begin
                i = i + 1;
                T_i = T_i + 1.0 / (2.0 * $itor(i) - 1.0);
            end

            deliverable_normalized = $itor(i) - (2.0 * $itor(i) - 1.0) * (T_i - target);
        end
    end

    // Convert to ml
    deliverable = deliverable_normalized * $itor(C);
end

assign result = deliverable;

endmodule